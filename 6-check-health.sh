#!/bin/bash
# Health Check and Diagnostic Script
# Use this to diagnose deployment issues

# Don't exit on error - we want to run all checks
set +e

echo "=== Django App Health Check ==="
echo ""

# Check if containers are running
echo "1. Checking container status..."
docker compose ps
echo ""

# Check web container logs
echo "2. Checking web container logs (last 50 lines)..."
docker compose logs --tail=50 web || echo "⚠ Could not read web logs"
echo ""

# Check nginx container logs
echo "3. Checking nginx container logs (last 50 lines)..."
docker compose logs --tail=50 nginx || echo "⚠ Could not read nginx logs"
echo ""

# Test web container directly
echo "4. Testing web container directly..."
if docker compose exec -T web curl -f http://localhost:8000/ > /dev/null 2>&1; then
    echo "✓ Web container is responding on port 8000"
else
    echo "✗ Web container is NOT responding on port 8000"
    echo "  Checking if gunicorn is running..."
    docker compose exec -T web ps aux | grep gunicorn || echo "  ✗ Gunicorn is not running"
fi
echo ""

# Test nginx connectivity to web
echo "5. Testing nginx connectivity to web container..."
if docker compose exec -T nginx wget -q -O- http://web:8000/ > /dev/null 2>&1; then
    echo "✓ Nginx can reach web container"
else
    echo "✗ Nginx cannot reach web container"
    echo "  This is likely the cause of 502 Bad Gateway"
fi
echo ""

# Check network
echo "6. Checking Docker network..."
NETWORK_NAME=$(docker compose ps -q web 2>/dev/null | xargs docker inspect --format '{{range $net, $v := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null | head -1)
if [ -n "$NETWORK_NAME" ]; then
    echo "  Network: $NETWORK_NAME"
    docker network inspect "$NETWORK_NAME" 2>/dev/null | grep -A 5 "Containers" || echo "  ⚠ Could not inspect network details"
else
    echo "  ⚠ Could not determine network name"
fi
echo ""

# Check environment variables
echo "7. Checking environment variables..."
if docker compose exec -T web env | grep -q "DJANGO_ENVIRONMENT=production"; then
    echo "✓ DJANGO_ENVIRONMENT is set correctly"
else
    echo "✗ DJANGO_ENVIRONMENT is not set correctly"
fi
echo ""

# Check static files
echo "8. Checking static files..."
if docker compose exec -T web test -d /app/staticfiles && [ "$(docker compose exec -T web ls -A /app/staticfiles 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "✓ Static files directory exists and has files"
else
    echo "⚠ Static files directory is empty or missing"
    echo "  Run: docker compose exec web python manage.py collectstatic --noinput"
fi
echo ""

# Test HTTP endpoint
echo "9. Testing HTTP endpoint..."
if curl -f http://localhost:80 > /dev/null 2>&1; then
    echo "✓ HTTP endpoint is responding"
else
    echo "✗ HTTP endpoint is not responding"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "000")
    echo "  HTTP Status Code: $HTTP_CODE"
    if [ "$HTTP_CODE" = "502" ]; then
        echo "  → 502 Bad Gateway: Nginx cannot connect to Django app"
        echo "  → Check web container logs: docker compose logs web"
    fi
fi
echo ""

# Summary
echo "=== Summary ==="
echo "If you see 502 errors, common fixes:"
echo "1. Restart services: docker compose restart"
echo "2. Rebuild web container: docker compose build --no-cache web && docker compose up -d"
echo "3. Check web logs: docker compose logs -f web"
echo "4. Ensure .env.production exists and has correct values"
echo "5. Wait for health check: docker compose ps (check health status)"

