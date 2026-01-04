#!/bin/bash
set -e

DOMAIN="vumgames.com"
EMAIL="you@example.com"

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
