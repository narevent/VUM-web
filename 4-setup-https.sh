#!/bin/bash
# Setup HTTPS with Let's Encrypt
# Run this after your app is working on HTTP

set -e

echo "=== Setting up HTTPS with Let's Encrypt ==="

# Check if app is running
if ! docker compose ps | grep -q "Up"; then
    echo "ERROR: Application is not running!"
    echo "Please run 3-start-app.sh first to start the application."
    exit 1
fi

# Get email for Let's Encrypt
read -p "Enter your email for Let's Encrypt notifications: " EMAIL

if [ -z "$EMAIL" ]; then
    echo "ERROR: Email is required"
    exit 1
fi

# Obtain SSL certificate
echo "Obtaining SSL certificate..."
docker compose -f docker-compose.yaml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d vumgames.com \
    -d www.vumgames.com

if [ $? -ne 0 ]; then
    echo "Error: Failed to obtain SSL certificate"
    echo "Make sure:"
    echo "1. Your domain DNS is pointing to this server"
    echo "2. Ports 80 and 443 are open in your firewall"
    echo "3. Your app is running (docker compose ps should show services up)"
    echo "4. The nginx container can access /var/www/certbot"
    exit 1
fi

echo "SSL certificate obtained successfully!"

# Verify certificate exists
if [ ! -d "/etc/letsencrypt/live/vumgames.com" ]; then
    echo "⚠ Warning: Certificate directory not found in host filesystem"
    echo "Certificate should be in Docker volume: certbot_conf"
fi

# Update nginx config with HTTPS (use the existing HTTPS config)
echo "Updating nginx configuration for HTTPS..."
if [ -f "nginx/conf.d/app.conf" ] && grep -q "ssl_certificate" nginx/conf.d/app.conf; then
    echo "✓ HTTPS configuration already exists in app.conf"
else
    # Create HTTPS config
    cat > nginx/conf.d/app.conf << 'EOF'
# HTTP - redirect all traffic to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name vumgames.com www.vumgames.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - main configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name vumgames.com www.vumgames.com;

    ssl_certificate /etc/letsencrypt/live/vumgames.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vumgames.com/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;

    client_max_body_size 100M;

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }

    location /static/ {
        alias /app/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /app/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    echo "✓ HTTPS configuration created"
fi

# Reload nginx to apply new configuration
echo "Reloading nginx configuration..."
docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload

# Wait for services to stabilize
echo "Waiting for services to stabilize..."
sleep 10

# Check status
echo ""
echo "=== Service Status ==="
docker compose ps

echo ""
echo "=== HTTPS Setup Complete! ==="
echo "Your site should now be accessible at: https://vumgames.com"
echo ""
echo "Testing HTTPS..."
sleep 5
if curl -k -f https://localhost:443 > /dev/null 2>&1 || curl -k -f https://vumgames.com > /dev/null 2>&1; then
    echo "✓ HTTPS is working!"
else
    echo "⚠ HTTPS may not be responding yet. Check logs with:"
    echo "  docker compose logs nginx"
    echo "  docker compose logs web"
fi

echo ""
echo "SSL certificates will auto-renew every 12 hours via the certbot container."
echo ""
echo "Useful commands:"
echo "  docker compose ps          # Check service status"
echo "  docker compose logs -f     # View all logs"
echo "  docker compose restart     # Restart all services"