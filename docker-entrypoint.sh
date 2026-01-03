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
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 60 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    --capture-output \
    website.wsgi:application

