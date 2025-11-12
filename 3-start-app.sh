#!/bin/bash
# Start Django Application (HTTP only)
# Run this before setting up HTTPS

set -e

echo "=== Starting Django Application ==="

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
    echo "Error: docker-compose.yaml not found!"
    echo "Please run this script from your app directory"
    exit 1
fi

# Stop any running containers
echo "Stopping any existing containers..."
docker compose down 2>/dev/null || true

# Remove the certbot service temporarily for initial setup
echo "Creating temporary docker-compose file for initial setup..."
cat > docker-compose.temp.yml << 'EOF'
version: '3.8'

services:
  web:
    build: .
    container_name: django_app
    restart: unless-stopped
    env_file:
      - .env.production
    volumes:
      - ./db.sqlite3:/app/db.sqlite3
      - ./media:/app/media
      - static_volume:/app/staticfiles
    networks:
      - app-network

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./media:/app/media
      - static_volume:/app/staticfiles
      - certbot_www:/var/www/certbot
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  static_volume:
  certbot_www:
EOF

# Build and start services
echo "Building Docker images (this may take a few minutes)..."
docker compose -f docker-compose.temp.yml build --no-cache

echo "Starting services..."
docker compose -f docker-compose.temp.yml up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Check if services are running
echo ""
echo "=== Service Status ==="
docker compose -f docker-compose.temp.yml ps

# Test the application
echo ""
echo "=== Testing Application ==="
echo "Checking if app is responding..."
sleep 5
if curl -f http://localhost:80 > /dev/null 2>&1; then
    echo "✓ Application is running!"
else
    echo "⚠ Application may not be responding yet. Check logs with:"
    echo "  docker compose -f docker-compose.temp.yml logs web"
fi

echo ""
echo "=== Application Started ==="
echo "Your app should be accessible at: http://vumgames.com"
echo ""
echo "To view logs:"
echo "  docker compose -f docker-compose.temp.yml logs -f web"
echo ""
echo "Next step: Run 4-setup-https.sh to enable HTTPS"