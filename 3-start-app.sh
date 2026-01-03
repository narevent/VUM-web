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
echo "Waiting for services to start (this may take up to 60 seconds)..."
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker compose ps | grep -q "django_app.*Up.*healthy"; then
        echo "✓ Web container is healthy"
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
    echo "  Waiting... ($WAITED/$MAX_WAIT seconds)"
done

# Check if web container is running
if ! docker compose ps | grep -q "django_app.*Up"; then
    echo "⚠ Warning: Web container may not be running properly"
    echo "Checking logs..."
    docker compose logs --tail=30 web
fi

# Run migrations (if not already done by startup command)
echo "Verifying database migrations..."
docker compose exec -T web python manage.py migrate --noinput || echo "⚠ Migration check failed, but continuing..."

# Collect static files (if not already done by startup command)
echo "Verifying static files..."
docker compose exec -T web python manage.py collectstatic --noinput || echo "⚠ Static collection check failed, but continuing..."

# Check if services are running
echo ""
echo "=== Service Status ==="
docker compose -f docker-compose.yaml ps

# Wait a bit more for nginx to be ready
echo ""
echo "Waiting for nginx to be ready..."
sleep 10

# Test the application
echo ""
echo "=== Testing Application ==="
echo "Checking if app is responding..."
for i in {1..6}; do
    if curl -f http://localhost:80 > /dev/null 2>&1; then
        echo "✓ Application is running and responding!"
        break
    else
        if [ $i -eq 6 ]; then
            echo "✗ Application is not responding after multiple attempts"
            echo ""
            echo "Running diagnostics..."
            ./6-check-health.sh || echo "Run ./6-check-health.sh manually for detailed diagnostics"
        else
            echo "  Attempt $i/6 failed, retrying in 5 seconds..."
            sleep 5
        fi
    fi
done

echo ""
echo "=== Application Started ==="
echo "Your app should be accessible at: http://vumgames.com"
echo ""
echo "To view logs:"
echo "  docker compose -f docker-compose.yaml logs -f web"
echo "  docker compose -f docker-compose.yaml logs -f nginx"
echo ""
echo "Next step: Run 4-setup-https.sh to enable HTTPS"