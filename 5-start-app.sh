#!/bin/bash
# Start Django Application (HTTP only)
# Run this to start the application on HTTP

set -e

echo "=== Starting Django Application (HTTP) ==="

# Check prerequisites
if [ ! -f ".env.production" ]; then
    echo "ERROR: .env.production not found!"
    echo "Run ./1-check-prerequisites.sh first"
    exit 1
fi

if [ ! -f "nginx/conf.d/app-http.conf" ]; then
    echo "ERROR: nginx/conf.d/app-http.conf not found!"
    echo "Run ./2-setup-configs.sh first"
    exit 1
fi

# Ensure db directory exists
mkdir -p db media

# Activate HTTP-only configuration
echo "Activating HTTP-only nginx configuration..."
rm -f nginx/conf.d/app.conf
cp nginx/conf.d/app-http.conf nginx/conf.d/app.conf
echo "✓ HTTP configuration activated"

# Ensure SECURE_SSL_REDIRECT is False
if grep -q "^SECURE_SSL_REDIRECT=True" .env.production; then
    echo "⚠ Disabling HTTPS redirect for initial setup..."
    sed -i 's/^SECURE_SSL_REDIRECT=True/SECURE_SSL_REDIRECT=False/' .env.production
fi

# Stop any running containers
echo ""
echo "Stopping existing containers..."
docker compose down 2>/dev/null || true
sleep 2

# Clean up any orphaned containers
docker compose rm -f 2>/dev/null || true

# Build services
echo ""
echo "Building Docker images..."
docker compose build --no-cache

# Start services
echo ""
echo "Starting services..."
docker compose up -d

# Wait for services to be healthy
echo ""
echo "Waiting for services to start (up to 2 minutes)..."
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker compose ps | grep -q "django_app.*Up"; then
        echo "✓ Django container is running"
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
    printf "."
done
echo ""

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "⚠ Warning: Containers took longer than expected to start"
fi

# Wait additional time for Django to initialize
echo "Waiting for Django to initialize..."
sleep 15

# Check service status
echo ""
echo "=== Service Status ==="
docker compose ps

# Test the application
echo ""
echo "=== Testing Application ==="
echo "Testing HTTP access..."

SUCCESS=0
for i in {1..10}; do
    echo "Attempt $i/10..."
    
    # Try localhost
    if curl -f -s -o /dev/null http://localhost:80; then
        echo "✓ Application is responding on HTTP!"
        SUCCESS=1
        break
    fi
    
    # Try via IP
    if curl -f -s -o /dev/null http://127.0.0.1:80; then
        echo "✓ Application is responding on HTTP!"
        SUCCESS=1
        break
    fi
    
    if [ $i -lt 10 ]; then
        echo "  Not ready yet, waiting 5 seconds..."
        sleep 5
    fi
done

echo ""
if [ $SUCCESS -eq 1 ]; then
    echo "=== ✓ Application Started Successfully ==="
    echo ""
    echo "Your app is running on HTTP:"
    echo "  • http://localhost"
    echo "  • http://vumgames.com (if DNS is configured)"
    echo ""
    echo "View logs:"
    echo "  docker compose logs -f web"
    echo "  docker compose logs -f nginx"
    echo ""
    echo "Next step: Run ./6-setup-https.sh to enable HTTPS"
else
    echo "=== ⚠ Application may not be responding correctly ==="
    echo ""
    echo "Troubleshooting:"
    echo "1. Check Django logs:"
    echo "   docker compose logs web"
    echo ""
    echo "2. Check nginx logs:"
    echo "   docker compose logs nginx"
    echo ""
    echo "3. Run health check:"
    echo "   ./8-check-health.sh"
    echo ""
    echo "4. Try accessing directly:"
    echo "   curl -v http://localhost:80"
fi