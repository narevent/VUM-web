#!/bin/bash
# Update Django Application
# Use this script to pull latest changes and redeploy

set -e

echo "=== Updating Django Application ==="

# Pull latest changes
echo "Pulling latest changes from GitHub..."
git pull origin main || git pull origin master

# Rebuild and restart services
echo "Rebuilding Docker images..."
docker compose build --no-cache web

echo "Restarting services..."
docker compose up -d

# Wait for services
echo "Waiting for services to restart..."
sleep 10

# Run migrations if needed
echo "Running database migrations..."
docker compose exec web python manage.py migrate --noinput

# Collect static files
echo "Collecting static files..."
docker compose exec web python manage.py collectstatic --noinput

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