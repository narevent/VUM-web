#!/bin/bash
# Start Django Application (HTTP only)
# Run this before setting up HTTPS

set -e

echo "=== Starting Django Application ==="

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "ERROR: .env.production file not found!"
    echo "Please create .env.production with required environment variables."
    echo "Required variables:"
    echo "  - SECRET_KEY"
    echo "  - DEBUG=False"
    echo "  - ALLOWED_HOSTS=vumgames.com,www.vumgames.com"
    echo "  - DJANGO_ENVIRONMENT=production"
    exit 1
fi

# Use HTTP-only nginx config for initial setup
echo "Using HTTP-only nginx configuration..."
if [ -f "nginx/conf.d/app-http.conf" ]; then
    cp nginx/conf.d/app-http.conf nginx/conf.d/app.conf
    echo "✓ HTTP configuration activated"
else
    echo "⚠ Warning: app-http.conf not found, using existing app.conf"
fi

# Stop any running containers
echo "Stopping any existing containers..."
docker compose down 2>/dev/null || true

# Build and start services
echo "Building Docker images (this may take a few minutes)..."
docker compose -f docker-compose.yaml build --no-cache

echo "Starting services..."
docker compose -f docker-compose.yaml up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 15

# Run migrations
echo "Running database migrations..."
docker compose exec -T web python manage.py migrate --noinput || echo "⚠ Migration failed, check logs"

# Collect static files
echo "Collecting static files..."
docker compose exec -T web python manage.py collectstatic --noinput || echo "⚠ Static collection failed, check logs"

# Check if services are running
echo ""
echo "=== Service Status ==="
docker compose -f docker-compose.yaml ps

# Test the application
echo ""
echo "=== Testing Application ==="
echo "Checking if app is responding..."
sleep 5
if curl -f http://localhost:80 > /dev/null 2>&1; then
    echo "✓ Application is running!"
else
    echo "⚠ Application may not be responding yet. Check logs with:"
    echo "  docker compose -f docker-compose.yaml logs web"
    echo "  docker compose -f docker-compose.yaml logs nginx"
fi

echo ""
echo "=== Application Started ==="
echo "Your app should be accessible at: http://vumgames.com"
echo ""
echo "To view logs:"
echo "  docker compose -f docker-compose.yaml logs -f web"
echo "  docker compose -f docker-compose.yaml logs -f nginx"
echo ""
echo "Next step: Run 4-setup-https.sh to enable HTTPS"