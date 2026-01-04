#!/bin/bash
set -e

read -p "Domain (example.com): " DOMAIN
read -p "Email for Let's Encrypt: " EMAIL

echo "=== SSL CERTIFICATE SETUP ==="

# Stop any running containers
docker compose down

# 1. Start with HTTP config
echo "1. Creating HTTP config..."
cat > docker/nginx/app.conf << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://django;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 2. Start containers
echo "2. Starting containers..."
docker compose up -d web nginx

# 3. Wait for services
echo "3. Waiting for services to be ready..."
sleep 10

# 4. Test web service is accessible internally
echo "4. Testing web service..."
docker exec web curl -I http://localhost:8000 || echo "Web service not responding internally"

# 5. Request certificates
echo "5. Requesting SSL certificates..."
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  -d $DOMAIN \
  -d www.$DOMAIN \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  --non-interactive \
  --force-renewal

# 6. Check if certificates were created
echo "6. Verifying certificates..."
if docker exec nginx ls /etc/letsencrypt/live/$DOMAIN/fullchain.pem 2>/dev/null; then
    echo "✅ Certificates created successfully"
else
    echo "❌ Certificate creation failed"
    echo "Trying alternative method with standalone mode..."
    
    # Stop nginx to free port 80
    docker compose stop nginx
    
    # Use standalone mode
    docker compose run --rm --service-ports certbot certonly \
      --standalone \
      -d $DOMAIN \
      -d www.$DOMAIN \
      --email $EMAIL \
      --agree-tos \
      --no-eff-email \
      --non-interactive \
      --force-renewal
    
    # Start nginx again
    docker compose start nginx
fi

# 7. Create HTTPS config
echo "7. Creating HTTPS configuration..."
cat > docker/nginx/app.conf << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    client_max_body_size 20M;

    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    location /media/ {
        alias /app/media/;
        expires 1y;
        add_header Cache-Control "public";
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://django;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        proxy_connect_timeout 75s;
        proxy_send_timeout 3600s;
        proxy_read_timeout 3600s;
    }
}
EOF

# 8. Restart nginx
echo "8. Restarting nginx with HTTPS..."
docker compose restart nginx

# 9. Test SSL
echo "9. Testing SSL configuration..."
sleep 3
curl -I https://$DOMAIN || echo "SSL test failed, but configuration might still be OK"

echo "✅ SSL setup complete!"
echo "Your site should be accessible at:"
echo "  http://$DOMAIN (redirects to HTTPS)"
echo "  https://$DOMAIN"