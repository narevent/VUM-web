#!/bin/bash
# Debug startup issues
# Use this to see why the Django app isn't starting

set +e

echo "=== Debugging Django App Startup ==="
echo ""

# Check if container exists
echo "1. Checking if container exists..."
if docker ps -a | grep -q django_app; then
    echo "✓ Container exists"
    docker ps -a | grep django_app
else
    echo "✗ Container does not exist"
    echo "  Try: docker compose up -d web"
    exit 1
fi
echo ""

# Check container status
echo "2. Container status..."
docker compose ps web
echo ""

# Check recent logs
echo "3. Recent container logs (last 100 lines)..."
docker compose logs --tail=100 web
echo ""

# Check if gunicorn is running
echo "4. Checking if gunicorn process is running..."
if docker compose exec -T web ps aux 2>/dev/null | grep -q gunicorn; then
    echo "✓ Gunicorn is running"
    docker compose exec -T web ps aux | grep gunicorn
else
    echo "✗ Gunicorn is NOT running"
    echo ""
    echo "5. Checking what processes ARE running..."
    docker compose exec -T web ps aux 2>/dev/null || echo "  Cannot execute commands in container"
fi
echo ""

# Check port 8000
echo "6. Checking if port 8000 is listening..."
if docker compose exec -T web netstat -tlnp 2>/dev/null | grep -q 8000 || docker compose exec -T web ss -tlnp 2>/dev/null | grep -q 8000; then
    echo "✓ Port 8000 is listening"
    docker compose exec -T web netstat -tlnp 2>/dev/null | grep 8000 || docker compose exec -T web ss -tlnp 2>/dev/null | grep 8000
else
    echo "✗ Port 8000 is NOT listening"
fi
echo ""

# Test connection from inside container
echo "7. Testing connection from inside container..."
if docker compose exec -T web curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo "✓ Can connect to http://localhost:8000 from inside container"
    HTTP_CODE=$(docker compose exec -T web curl -s -o /dev/null -w '%{http_code}' http://localhost:8000 2>/dev/null || echo "000")
    echo "  HTTP Status: $HTTP_CODE"
else
    echo "✗ Cannot connect to http://localhost:8000 from inside container"
fi
echo ""

# Check environment variables
echo "8. Checking critical environment variables..."
docker compose exec -T web env 2>/dev/null | grep -E "DJANGO_ENVIRONMENT|SECRET_KEY|ALLOWED_HOSTS|DEBUG" || echo "  Cannot check environment variables"
echo ""

# Check if .env.production is being read
echo "9. Checking if .env.production exists on host..."
if [ -f ".env.production" ]; then
    echo "✓ .env.production exists"
    echo "  File size: $(wc -l < .env.production) lines"
    if grep -q "SECRET_KEY" .env.production; then
        echo "  ✓ Contains SECRET_KEY"
    else
        echo "  ✗ Missing SECRET_KEY"
    fi
    if grep -q "ALLOWED_HOSTS" .env.production; then
        echo "  ✓ Contains ALLOWED_HOSTS"
    else
        echo "  ✗ Missing ALLOWED_HOSTS"
    fi
else
    echo "✗ .env.production does NOT exist"
    echo "  This is required for the app to start!"
fi
echo ""

# Check database file
echo "10. Checking database file..."
if [ -f "db/db.sqlite3" ]; then
    echo "✓ db/db.sqlite3 exists"
    echo "  File size: $(du -h db/db.sqlite3 | cut -f1)"
elif [ -f "db.sqlite3" ]; then
    echo "⚠ Old db.sqlite3 found in root directory"
    echo "  Run ./8-migrate-db.sh to migrate to new location (db/db.sqlite3)"
else
    echo "⚠ db/db.sqlite3 does not exist (will be created on first migration)"
    if [ ! -d "db" ]; then
        echo "  Creating db/ directory..."
        mkdir -p db
    fi
fi
echo ""

# Try to run a simple Django command
echo "11. Testing Django setup..."
if docker compose exec -T web python manage.py check --deploy 2>&1 | head -20; then
    echo "✓ Django check passed"
else
    echo "⚠ Django check had issues (see above)"
fi
echo ""

# Summary and recommendations
echo "=== Summary and Recommendations ==="
echo ""
if docker compose ps web | grep -q "unhealthy"; then
    echo "Container is UNHEALTHY. Common causes:"
    echo "1. Django app is crashing on startup - check logs above"
    echo "2. Missing or incorrect .env.production file"
    echo "3. Database migration issues"
    echo "4. Missing dependencies"
    echo ""
    echo "Try these fixes:"
    echo "  docker compose logs -f web          # Watch logs in real-time"
    echo "  docker compose restart web          # Restart the container"
    echo "  docker compose exec web python manage.py check  # Check Django config"
fi

if ! docker compose exec -T web ps aux 2>/dev/null | grep -q gunicorn; then
    echo ""
    echo "Gunicorn is not running. Try:"
    echo "  docker compose restart web"
    echo "  docker compose logs web | tail -50"
fi

