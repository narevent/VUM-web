#!/bin/bash
set -e

echo "=== DEPLOY UPDATE ==="

git pull

docker compose build
docker compose up -d

docker image prune -f

echo "✅ Update complete"
