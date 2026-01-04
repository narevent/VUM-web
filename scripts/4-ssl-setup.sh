#!/bin/bash
set -e

read -p "Domain (example.com): " DOMAIN
read -p "Email for Let's Encrypt: " EMAIL

echo "=== SSL CERTIFICATE SETUP ==="

# Ensure directories exist
mkdir -p docker/nginx

# Create HTTP config for initial certificate request
cat > docker/nginx/app.conf << 'EOF'
server {
    listen 80;
    server_name __DOMAIN__ www.__DOMAIN__;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
        try_files $uri =404;
    }

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Replace domain placeholder
sed -i "s/__DOMAIN__/$DOMAIN/g" docker/nginx/app.conf

echo "Starting containers with HTTP config..."
docker compose up -d web nginx

echo "Waiting for services to be ready..."
sleep 10

echo "Requesting SSL certificates..."
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

echo "Verifying certificates were created..."
if docker exec nginx ls /etc/letsencrypt/live/$DOMAIN/fullchain.pem; then
    echo "✅ Certificates created successfully"
else
    echo "❌ Certificate creation failed"
    exit 1
fi

echo "Creating HTTPS nginx config..."
cat > docker/nginx/app.conf << 'EOF'
server {
    listen 80;
    server_name __DOMAIN__ www.__DOMAIN__;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name __DOMAIN__ www.__DOMAIN__;

    ssl_certificate /etc/letsencrypt/live/__DOMAIN__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__DOMAIN__/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    client_max_body_size 20M;

    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /app/media/;
        expires 1y;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
}
EOF

# Replace domain placeholder
sed -i "s/__DOMAIN__/$DOMAIN/g" docker/nginx/app.conf

echo "Restarting nginx with HTTPS config..."
docker compose restart nginx

echo "✅ SSL setup complete! Your site should now be accessible at https://$DOMAIN"