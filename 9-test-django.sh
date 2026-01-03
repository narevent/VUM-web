#!/bin/bash
# Test Django configuration before starting
# Run this to check if Django is properly configured

set +e

echo "=== Testing Django Configuration ==="
echo ""

# Check if container is running
if ! docker compose ps web | grep -q "Up"; then
    echo "✗ Web container is not running"
    echo "  Start it with: docker compose up -d web"
    exit 1
fi

echo "1. Testing Django system check..."
docker compose exec -T web python manage.py check --deploy
CHECK_EXIT=$?
if [ $CHECK_EXIT -eq 0 ]; then
    echo "✓ Django system check passed"
else
    echo "✗ Django system check FAILED"
    echo "  This is likely why gunicorn won't start"
fi
echo ""

echo "2. Testing Django settings import..."
docker compose exec -T web python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website.settings')
import django
django.setup()
from django.conf import settings
print('✓ Settings loaded successfully')
print(f'  DEBUG: {settings.DEBUG}')
print(f'  ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}')
print(f'  DATABASE: {settings.DATABASES[\"default\"][\"NAME\"]}')
"
SETTINGS_EXIT=$?
if [ $SETTINGS_EXIT -ne 0 ]; then
    echo "✗ Failed to import Django settings"
    echo "  Check your .env.production file and settings files"
fi
echo ""

echo "3. Testing WSGI application import..."
docker compose exec -T web python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website.settings')
from website.wsgi import application
print('✓ WSGI application loaded successfully')
print(f'  Application type: {type(application)}')
"
WSGI_EXIT=$?
if [ $WSGI_EXIT -ne 0 ]; then
    echo "✗ Failed to import WSGI application"
    echo "  This will prevent gunicorn from starting"
fi
echo ""

echo "4. Testing database connection..."
docker compose exec -T web python manage.py dbshell --command "SELECT 1;" 2>&1 | head -5
DB_EXIT=$?
if [ $DB_EXIT -eq 0 ]; then
    echo "✓ Database connection works"
else
    echo "⚠ Database connection test had issues (may be OK if database doesn't exist yet)"
fi
echo ""

echo "5. Checking environment variables..."
docker compose exec -T web env | grep -E "DJANGO_ENVIRONMENT|SECRET_KEY|ALLOWED_HOSTS|DEBUG" | sed 's/=.*/=***/' || echo "  Could not check environment variables"
echo ""

# Summary
echo "=== Summary ==="
if [ $CHECK_EXIT -ne 0 ] || [ $SETTINGS_EXIT -ne 0 ] || [ $WSGI_EXIT -ne 0 ]; then
    echo "✗ Django configuration has issues"
    echo ""
    echo "Common fixes:"
    echo "1. Check .env.production file exists and has correct values"
    echo "2. Check logs: docker compose logs web"
    echo "3. Verify SECRET_KEY is set"
    echo "4. Verify ALLOWED_HOSTS includes your domain"
    exit 1
else
    echo "✓ Django configuration looks good"
    echo "  If gunicorn still won't start, check: docker compose logs -f web"
fi

