#!/bin/bash
set -e

DOMAIN="vumgames.com"

echo "=== FIRST DEPLOY (HTTP ONLY) ==="

# Safety checks
if [ ! -f ".env.production" ]; then
  echo "❌ .env.production not found"
  exit 1
fi

# Use HTTP-only nginx config
cp docker/nginx/app.conf.http docker/nginx/app.conf

echo "Building containers..."
docker compose build

echo "Starting web + nginx (HTTP only)..."
docker compose up -d web nginx

echo "✅ HTTP deploy complete"
echo "➡️ Next: run scripts/4-ssl-setup.sh"
