#!/bin/bash
# Start Django Application (HTTP only)
# Run this before setting up HTTPS

set -e

echo "=== Starting Django Application ==="

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
sleep 10

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
fi

echo ""
echo "=== Application Started ==="
echo "Your app should be accessible at: http://vumgames.com"
echo ""
echo "To view logs:"
echo "  docker compose -f docker-compose.yaml logs -f web"
echo ""
echo "Next step: Run 4-setup-https.sh to enable HTTPS"