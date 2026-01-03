#!/bin/bash
# Deep debugging script to find why gunicorn isn't running

set +e

echo "=== Deep Debugging Gunicorn Issue ==="
echo ""

# Check container status
echo "1. Container status:"
docker compose ps web
echo ""

# Check if container is actually running
if ! docker compose ps web | grep -q "Up"; then
    echo "✗ Container is not running!"
    exit 1
fi

# Get the actual process tree
echo "2. Process tree (PID 1 and children):"
docker compose exec -T web ps -ef 2>/dev/null || docker compose exec -T web ps aux 2>/dev/null
echo ""

# Check what PID 1 actually is
echo "3. Main process (PID 1) details:"
echo "  Command:"
docker compose exec -T web sh -c "cat /proc/1/cmdline 2>/dev/null | tr '\0' ' '" || echo "  Cannot read"
echo ""
echo "  Status:"
docker compose exec -T web sh -c "cat /proc/1/status 2>/dev/null | head -10" || echo "  Cannot read"
echo ""

# Check if entrypoint script is running
echo "4. Checking entrypoint script:"
if docker compose exec -T web test -f /docker-entrypoint.sh; then
    echo "✓ Entrypoint script exists"
    docker compose exec -T web ls -la /docker-entrypoint.sh
else
    echo "✗ Entrypoint script not found"
fi
echo ""

# Try to manually start gunicorn to see error
echo "5. Attempting to manually start gunicorn to see errors:"
echo "  (This will show what happens when gunicorn tries to start)"
docker compose exec -T web sh -c "cd /app && timeout 5 gunicorn --bind 0.0.0.0:8000 --workers 1 --timeout 5 website.wsgi:application 2>&1 | head -20" || echo "  Gunicorn failed to start (see errors above)"
echo ""

# Check if port is in use by something else
echo "6. Checking what's using port 8000:"
docker compose exec -T web sh -c "lsof -i :8000 2>/dev/null || fuser 8000/tcp 2>/dev/null || echo '  No process found on port 8000'"
echo ""

# Check recent logs for gunicorn startup
echo "7. Recent logs (last 30 lines) looking for gunicorn:"
docker compose logs --tail=30 web | grep -i gunicorn || echo "  No gunicorn mentions in recent logs"
echo ""

# Check for any error patterns
echo "8. Looking for errors in logs:"
docker compose logs --tail=50 web | grep -i -E "error|exception|traceback|failed|fatal" | tail -10 || echo "  No obvious errors found"
echo ""

# Test WSGI import directly
echo "9. Testing WSGI import:"
docker compose exec -T web python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website.settings')
try:
    from website.wsgi import application
    print('✓ WSGI application imported successfully')
    print(f'  Type: {type(application)}')
except Exception as e:
    print(f'✗ Failed to import WSGI: {e}')
    import traceback
    traceback.print_exc()
"
echo ""

# Check environment
echo "10. Environment variables:"
docker compose exec -T web env | grep -E "DJANGO|PYTHON|PATH" | sort
echo ""

# Summary
echo "=== Analysis ==="
MAIN_PROC=$(docker compose exec -T web sh -c "cat /proc/1/comm 2>/dev/null" | tr -d '\n\r ')
echo "Main process: $MAIN_PROC"

if [ "$MAIN_PROC" = "gunicorn" ] || [ "$MAIN_PROC" = "python" ]; then
    echo "✓ Main process appears to be gunicorn/python"
else
    echo "⚠ Main process is '$MAIN_PROC' (expected: gunicorn or python)"
    echo "  This suggests the entrypoint script may not have exec'd gunicorn"
fi

