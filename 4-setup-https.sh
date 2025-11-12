#!/bin/bash
# Setup HTTPS with Let's Encrypt
# Run this after your app is working on HTTP

set -e

echo "=== Setting up HTTPS with Let's Encrypt ==="

# Get email for Let's Encrypt
read -p "Enter your email for Let's Encrypt notifications: " EMAIL

# Obtain SSL certificate
echo "Obtaining SSL certificate..."
docker compose -f docker-compose.temp.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d vumgames.com \
    -d www.vumgames.com

if [ $? -ne 0 ]; then
    echo "Error: Failed to obtain SSL certificate"
    echo "Make sure:"
    echo "1. Your domain DNS is pointing to this server"
    echo "2. Ports 80 and 443 are open in your firewall"
    echo "3. Your app is running (docker compose ps should show services up)"
    exit 1
fi

echo "SSL certificate obtained successfully!"

# Update nginx config with HTTPS
echo "Updating nginx configuration for HTTPS..."
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

# Stop temporary setup
echo "Stopping temporary setup..."
docker compose -f docker-compose.temp.yml down

# Start full setup with HTTPS
echo "Starting services with HTTPS..."
docker compose up -d

# Wait for services to start
echo "Waiting for services to start..."
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
if curl -k -f https://localhost:443 > /dev/null 2>&1; then
    echo "✓ HTTPS is working!"
else
    echo "⚠ HTTPS may not be responding yet. Check logs with:"
    echo "  docker compose logs nginx"
fi

echo ""
echo "SSL certificates will auto-renew every 12 hours via the certbot container."
echo ""
echo "Useful commands:"
echo "  docker compose ps          # Check service status"
echo "  docker compose logs -f     # View all logs"
echo "  docker compose restart     # Restart all services"