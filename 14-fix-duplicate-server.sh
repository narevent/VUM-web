#!/bin/bash
# Fix duplicate server block in app.conf

set -e

echo "=== Fixing Duplicate Server Block ==="
echo ""

# Remove old app.conf
echo "1. Removing old app.conf..."
rm -f nginx/conf.d/app.conf
echo "✓ Removed old config"

# Copy HTTP config as the active config
echo ""
echo "2. Activating HTTP-only configuration..."
if [ -f "nginx/conf.d/app-http.conf" ]; then
    cp nginx/conf.d/app-http.conf nginx/conf.d/app.conf
    echo "✓ HTTP configuration activated"
else
    echo "✗ app-http.conf not found!"
    exit 1
fi

# Verify only one server block on port 80
echo ""
echo "3. Verifying configuration..."
SERVER_COUNT=$(grep -c "server {" nginx/conf.d/app.conf)
LISTEN_80_COUNT=$(grep -c "listen.*80" nginx/conf.d/app.conf)

echo "  Server blocks: $SERVER_COUNT"
echo "  Listen 80 directives: $LISTEN_80_COUNT"

if [ "$SERVER_COUNT" -gt 1 ] || [ "$LISTEN_80_COUNT" -gt 2 ]; then
    echo "✗ Still has duplicate server blocks!"
    exit 1
fi

echo "✓ Configuration looks good"

# Test nginx configuration
echo ""
echo "4. Testing nginx configuration..."
if docker compose exec -T nginx nginx -t 2>&1; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration still has errors!"
    echo ""
    echo "Checking for other config files..."
    ls -la nginx/conf.d/*.conf
    exit 1
fi

# Restart nginx to apply changes
echo ""
echo "5. Restarting nginx container..."
docker compose restart nginx
sleep 5

# Check nginx status
echo ""
echo "6. Checking nginx status..."
docker compose ps nginx

# Check if nginx is running without errors
echo ""
echo "7. Checking nginx logs for errors..."
sleep 2
if docker compose logs --tail=10 nginx | grep -i "emerg\|error" | grep -v "warn"; then
    echo "✗ Nginx has errors in logs!"
    docker compose logs --tail=20 nginx | grep -i "emerg\|error"
else
    echo "✓ No errors in nginx logs"
fi

echo ""
echo "=== Fix Complete ==="
echo "Nginx should now be running without duplicate server errors."
echo "Test with: curl http://localhost"

