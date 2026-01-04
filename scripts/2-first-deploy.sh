#!/bin/bash
set -e

read -p "Git repo URL: " REPO
read -p "Domain name (example.com): " DOMAIN

git clone $REPO app
cd app

echo "=== FIRST DEPLOY (HTTP ONLY) ==="

# Safety checks
if [ ! -f ".env.production" ]; then
  echo "⚠️ .env.production not found, creating from example"
  cp .env.production.example .env.production
  echo "❗ EDIT .env.production BEFORE CONTINUING"
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

