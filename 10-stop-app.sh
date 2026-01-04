#!/bin/bash
# Stop Application
# Stops all containers

set -e

echo "=== Stopping Application ==="

# Stop containers
docker compose down

echo ""
echo "✓ All containers stopped"
echo ""
echo "To start again: ./5-start-app.sh"
echo "To completely remove volumes: docker compose down -v"