#!/bin/bash
# Update Django Application
# Use this script to pull latest changes and redeploy

set -e

echo "=== Updating Django Application ==="

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "ERROR: .env.production file not found!"
    echo "Please ensure .env.production exists with required environment variables."
    exit 1
fi

# Pull latest changes
echo "Pulling latest changes from GitHub..."
git pull origin main || git pull origin master || echo "⚠ Could not pull from git, continuing with local changes..."

# Rebuild and restart services
echo "Rebuilding Docker images..."
docker compose build --no-cache web

echo "Restarting services..."
docker compose up -d

# Wait for services
echo "Waiting for services to restart..."
sleep 15

# Run migrations if needed
echo "Running database migrations..."
docker compose exec -T web python manage.py migrate --noinput || echo "⚠ Migration failed, check logs"

# Collect static files
echo "Collecting static files..."
docker compose exec -T web python manage.py collectstatic --noinput || echo "⚠ Static collection failed, check logs"

# Reload nginx if needed
echo "Reloading nginx..."
docker compose exec nginx nginx -s reload 2>/dev/null || echo "⚠ Nginx reload failed, may need restart"

# Check status
echo ""
echo "=== Service Status ==="
docker compose ps

echo ""
echo "=== Update Complete! ==="
echo "Your app has been updated to the latest version."
echo ""
echo "If you see any issues, check logs with:"
echo "  docker compose logs -f web"
echo "  docker compose logs -f nginx"