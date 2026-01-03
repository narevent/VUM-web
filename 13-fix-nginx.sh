#!/bin/bash
# Fix nginx configuration and reload

set -e

echo "=== Fixing Nginx Configuration ==="
echo ""

# Ensure HTTP config is active
echo "1. Activating HTTP-only configuration..."
if [ -f "nginx/conf.d/app-http.conf" ]; then
    cp nginx/conf.d/app-http.conf nginx/conf.d/app.conf
    echo "✓ HTTP configuration activated"
else
    echo "✗ app-http.conf not found!"
    exit 1
fi

# Test nginx configuration
echo ""
echo "2. Testing nginx configuration..."
if docker compose exec -T nginx nginx -t 2>&1; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has errors!"
    exit 1
fi

# Reload nginx
echo ""
echo "3. Reloading nginx..."
docker compose exec nginx nginx -s reload 2>&1 || {
    echo "⚠ Reload failed, restarting nginx container..."
    docker compose restart nginx
    sleep 3
}

# Check nginx status
echo ""
echo "4. Checking nginx status..."
docker compose ps nginx

# Test connectivity
echo ""
echo "5. Testing connectivity..."
sleep 2
if curl -s -f http://localhost > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost)
    echo "✓ Website is responding!"
    echo "  HTTP Status: $HTTP_CODE"
else
    echo "✗ Website is still not responding"
    echo ""
    echo "Checking nginx logs..."
    docker compose logs --tail=20 nginx | grep -i error || echo "  No errors in logs"
fi

echo ""
echo "=== Done ==="

