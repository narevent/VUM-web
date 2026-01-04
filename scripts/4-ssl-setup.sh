#!/bin/bash
set -e

read -p "Domain (example.com): " DOMAIN
read -p "Email for Let's Encrypt: " EMAIL

docker compose up -d nginx

echo "=== SSL CERTIFICATE SETUP ==="

docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  -d $DOMAIN \
  -d www.$DOMAIN \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email

echo "✅ Certificates issued"

echo "Enabling HTTPS config..."
cp docker/nginx/app.conf.https docker/nginx/app.conf

docker compose restart nginx

echo "🔒 HTTPS ENABLED"

