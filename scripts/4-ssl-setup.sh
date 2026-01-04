#!/bin/bash
set -e

read -p "Domain (example.com): " DOMAIN
read -p "Email for Let's Encrypt: " EMAIL

docker compose up -d nginx

echo "=== SSL CERTIFICATE SETUP ==="

echo "🔁 Forcing HTTP-only nginx config"
cp docker/nginx/app.conf.http docker/nginx/app.conf

docker compose down
docker compose up -d web nginx

echo "⏳ Waiting for nginx to become reachable..."
sleep 5

echo "🔍 Testing ACME challenge path..."
docker exec nginx sh -c "echo test > /var/www/certbot/.well-known/acme-challenge/test"

curl -s http://vumgames.com/.well-known/acme-challenge/test | grep test \
  || { echo '❌ ACME challenge NOT reachable'; exit 1; }

echo "✅ ACME challenge reachable"

echo "📜 Requesting certificates..."
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  -d $DOMAIN \
  -d www.$DOMAIN \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  --force-renewal

echo "🔍 Verifying cert files..."
docker exec nginx ls -l /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
  || { echo '❌ Certificates NOT created'; exit 1; }

echo "🔐 Enabling HTTPS nginx config"
cp docker/nginx/app.conf.https docker/nginx/app.conf

docker compose restart nginx

echo "✅ SSL SETUP COMPLETE"

