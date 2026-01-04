#!/bin/bash
# Quick Restart
# Restart services without rebuilding

set -e

echo "=== Quick Restart ==="

# Restart all services
echo "Restarting all services..."
docker compose restart

# Wait for services
echo "Waiting for services to restart..."
sleep 15

# Check status
echo ""
echo "=== Service Status ==="
docker compose ps

# Test connection
echo ""
echo "Testing connection..."
if curl -f -s -o /dev/null http://localhost:80 2>/dev/null; then
    echo "✓ HTTP is responding"
elif curl -f -s -k -o /dev/null https://localhost:443 2>/dev/null; then
    echo "✓ HTTPS is responding"
else
    echo "⚠ Application may not be responding yet"
    echo "  Wait a moment and try: curl http://localhost"
fi

echo ""
echo "View logs: docker compose logs -f"