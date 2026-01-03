#!/bin/bash
# Docker entrypoint script for Django application

set -e

echo "=========================================="
echo "Starting Django Application"
echo "=========================================="

# Create necessary directories
echo "Creating directories..."
mkdir -p /app/db /app/staticfiles /app/media
echo "✓ Directories created"

# Check environment
echo ""
echo "Environment check:"
echo "  DJANGO_ENVIRONMENT=${DJANGO_ENVIRONMENT:-not set}"
echo "  SECRET_KEY=${SECRET_KEY:+set (hidden)}${SECRET_KEY:-not set}"
echo "  ALLOWED_HOSTS=${ALLOWED_HOSTS:-not set}"

# Test Python/Django import
echo ""
echo "Testing Python imports..."
python -c "import django; print(f'✓ Django {django.get_version()}')" || exit 1

# Test settings import
echo ""
echo "Testing Django settings..."
python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website.settings')
import django
django.setup()
from django.conf import settings
print('✓ Settings loaded successfully')
print(f'  DEBUG: {settings.DEBUG}')
print(f'  Database: {settings.DATABASES[\"default\"][\"NAME\"]}')
" || {
    echo "✗ Failed to load Django settings"
    echo "Check your .env.production file and settings configuration"
    exit 1
}

# Run Django system check
echo ""
echo "Running Django system check..."
python manage.py check || {
    echo "✗ Django system check failed"
    echo "Running detailed check..."
    python manage.py check --deploy 2>&1 || true
    exit 1
}
echo "✓ System check passed"

# Collect static files
echo ""
echo "Collecting static files..."
python manage.py collectstatic --noinput || {
    echo "⚠ Warning: collectstatic failed, but continuing..."
}

# Run migrations
echo ""
echo "Running database migrations..."
python manage.py migrate --noinput || {
    echo "✗ Migration failed"
    exit 1
}
echo "✓ Migrations completed"

# Start gunicorn
echo ""
echo "=========================================="
echo "Starting Gunicorn server..."
echo "=========================================="

# Verify gunicorn is available
if ! command -v gunicorn &> /dev/null; then
    echo "✗ ERROR: gunicorn command not found!"
    echo "  Installing gunicorn..."
    pip install gunicorn || exit 1
fi

# Check if port 8000 is already in use
echo ""
echo "Checking if port 8000 is available..."
if command -v lsof &> /dev/null; then
    if lsof -i :8000 &> /dev/null; then
        echo "⚠ Port 8000 is in use, attempting to free it..."
        # Try to find and kill any process using port 8000
        lsof -ti :8000 | xargs -r kill -9 2>/dev/null || true
        sleep 2
    fi
elif command -v fuser &> /dev/null; then
    if fuser 8000/tcp &> /dev/null; then
        echo "⚠ Port 8000 is in use, attempting to free it..."
        fuser -k 8000/tcp 2>/dev/null || true
        sleep 2
    fi
fi

# Check for any existing gunicorn processes
echo "Checking for existing gunicorn processes..."
if pgrep -f gunicorn &> /dev/null; then
    echo "⚠ Found existing gunicorn processes, killing them..."
    pkill -9 -f gunicorn 2>/dev/null || true
    sleep 2
fi

# Verify port is now free
echo "Verifying port 8000 is free..."
if command -v python &> /dev/null; then
    python -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    s.bind(('0.0.0.0', 8000))
    s.close()
    print('✓ Port 8000 is available')
except OSError as e:
    print(f'✗ Port 8000 is still in use: {e}')
    exit(1)
" || {
    echo "✗ ERROR: Port 8000 is still in use. Cannot start gunicorn."
    echo "  Try: docker compose down && docker compose up -d"
    exit 1
}
fi

# Start gunicorn in foreground (exec replaces shell process)
echo ""
echo "Starting gunicorn on 0.0.0.0:8000..."
echo "Current PID: $$"
echo "About to exec gunicorn..."

# Test WSGI import one more time before starting
echo "Final WSGI import test..."
python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website.settings')
from website.wsgi import application
print('✓ WSGI application imported successfully')
" || {
    echo "✗ CRITICAL: WSGI import failed right before starting gunicorn!"
    exit 1
}

# Use exec to replace this shell process with gunicorn
# This ensures gunicorn becomes PID 1 and receives signals properly
# If exec fails, the container will exit (which is what we want)
echo "Executing gunicorn (this process will be replaced)..."
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 60 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    --preload \
    --name gunicorn \
    website.wsgi:application

