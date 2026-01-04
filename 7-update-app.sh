#!/bin/bash
# Update Django Application
# Pull latest changes and redeploy

set -e

echo "=== Updating Django Application ==="

# Check if app is running
if ! docker compose ps | grep -q "Up"; then
    echo "ERROR: Application is not running!"
    echo "Start it first with: ./3-start-app.sh"
    exit 1
fi

# Determine if HTTPS is active
HTTPS_ACTIVE=0
if [ -f "nginx/conf.d/app.conf" ] && grep -q "listen 443" nginx/conf.d/app.conf; then
    HTTPS_ACTIVE=1
    echo "HTTPS is active"
else
    echo "HTTP-only mode"
fi

# Pull latest changes from git
echo ""
echo "Pulling latest changes..."
if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
    echo "✓ Code updated from git"
else
    echo "⚠ Could not pull from git, continuing with local changes"
fi

# Rebuild Docker images
echo ""
echo "Rebuilding Docker images..."
docker compose build web

# Restart services
echo ""
echo "Restarting services..."
docker compose up -d

# Wait for services to restart
echo "Waiting for services to restart..."
sleep 20

# Run migrations
echo ""
echo "Running database migrations..."
if docker compose exec -T web python manage.py migrate --noinput; then
    echo "✓ Migrations completed"
else
    echo "⚠ Migrations may have failed, check logs"
fi

# Collect static files
echo ""
echo "Collecting static files..."
if docker compose exec -T web python manage.py collectstatic --noinput --clear; then
    echo "✓ Static files collected"
else
    echo "⚠ Static collection may have failed, check logs"
fi

# Reload nginx
echo ""
echo "Reloading nginx..."
if docker compose exec nginx nginx -s reload 2>/dev/null; then
    echo "✓ Nginx reloaded"
else
    echo "⚠ Nginx reload failed, restarting instead..."
    docker compose restart nginx
    sleep 5
fi

# Test the application
echo ""
echo "Testing application..."
sleep 5

SUCCESS=0
if [ $HTTPS_ACTIVE -eq 1 ]; then
    # Test HTTPS
    if curl -f -s -k -o /dev/null https://localhost:443; then
        echo "✓ HTTPS is responding"
        SUCCESS=1
    fi
else
    # Test HTTP
    if curl -f -s -o /dev/null http://localhost:80; then
        echo "✓ HTTP is responding"
        SUCCESS=1
    fi
fi

# Show status
echo ""
echo "=== Service Status ==="
docker compose ps

echo ""
if [ $SUCCESS -eq 1 ]; then
    echo "=== ✓ Update Complete! ==="
    echo ""
    echo "Your app has been updated successfully."
    if [ $HTTPS_ACTIVE -eq 1 ]; then
        echo "Access at: https://vumgames.com"
    else
        echo "Access at: http://vumgames.com"
    fi
else
    echo "=== ⚠ Update Completed with Warnings ==="
    echo ""
    echo "The update completed but the application may not be responding."
    echo ""
    echo "Troubleshooting:"
    echo "  • Check logs: docker compose logs -f"
    echo "  • Run health check: ./8-check-health.sh"
    echo "  • View Django logs: docker compose logs web"
    echo "  • View nginx logs: docker compose logs nginx"
fi