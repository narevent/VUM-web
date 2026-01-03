#!/bin/bash
# Check connectivity and diagnose why website isn't reachable

set +e

echo "=== Website Connectivity Diagnostic ==="
echo ""

# Check container status
echo "1. Container status:"
docker compose ps
echo ""

# Check if containers are running
WEB_RUNNING=$(docker compose ps web | grep -q "Up" && echo "yes" || echo "no")
NGINX_RUNNING=$(docker compose ps nginx | grep -q "Up" && echo "yes" || echo "no")

echo "2. Container status check:"
echo "  Web container: $WEB_RUNNING"
echo "  Nginx container: $NGINX_RUNNING"
echo ""

if [ "$WEB_RUNNING" != "yes" ] || [ "$NGINX_RUNNING" != "yes" ]; then
    echo "✗ One or more containers are not running!"
    echo "  Start them with: docker compose up -d"
    exit 1
fi

# Test web container directly
echo "3. Testing web container (port 8000):"
if docker compose exec -T web curl -s -f http://localhost:8000 > /dev/null 2>&1; then
    echo "✓ Web container is responding on port 8000"
    HTTP_CODE=$(docker compose exec -T web curl -s -o /dev/null -w '%{http_code}' http://localhost:8000 2>/dev/null)
    echo "  HTTP Status: $HTTP_CODE"
else
    echo "✗ Web container is NOT responding on port 8000"
fi
echo ""

# Test nginx -> web connectivity
echo "4. Testing nginx -> web container connectivity:"
if docker compose exec -T nginx wget -q -O- --timeout=5 http://web:8000/ > /dev/null 2>&1; then
    echo "✓ Nginx can reach web container"
else
    echo "✗ Nginx CANNOT reach web container"
    echo "  This is likely the problem!"
    echo ""
    echo "  Testing network connectivity..."
    docker compose exec -T nginx ping -c 2 web 2>&1 | head -5
    echo ""
    echo "  Testing port connectivity..."
    docker compose exec -T nginx nc -zv web 8000 2>&1 || docker compose exec -T nginx sh -c "timeout 2 bash -c '</dev/tcp/web/8000' 2>&1" || echo "  Port test failed"
fi
echo ""

# Test nginx directly
echo "5. Testing nginx (port 80):"
if curl -s -f http://localhost:80 > /dev/null 2>&1; then
    echo "✓ Nginx is responding on port 80"
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80 2>/dev/null)
    echo "  HTTP Status: $HTTP_CODE"
    if [ "$HTTP_CODE" = "502" ]; then
        echo "  ⚠ 502 Bad Gateway - Nginx cannot connect to web container"
    elif [ "$HTTP_CODE" = "400" ]; then
        echo "  ⚠ 400 Bad Request - Check nginx configuration"
    fi
else
    echo "✗ Nginx is NOT responding on port 80"
    echo "  Checking if port 80 is listening on host..."
    if command -v lsof &> /dev/null; then
        lsof -i :80 || echo "  Port 80 is not in use"
    fi
fi
echo ""

# Check nginx configuration
echo "6. Checking nginx configuration:"
if docker compose exec -T nginx nginx -t 2>&1; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has errors!"
fi
echo ""

# Check nginx logs
echo "7. Recent nginx error logs (last 20 lines):"
docker compose logs --tail=20 nginx 2>&1 | grep -i error || echo "  No errors in recent logs"
echo ""

# Check nginx access logs
echo "8. Recent nginx access logs (last 10 lines):"
docker compose logs --tail=10 nginx 2>&1 | grep -E "GET|POST" | tail -5 || echo "  No access logs"
echo ""

# Check port mappings
echo "9. Checking port mappings:"
echo "  Host port 80 -> Container:"
docker port nginx 2>/dev/null | grep 80 || echo "  Port mapping not found"
echo "  Host port 443 -> Container:"
docker port nginx 2>/dev/null | grep 443 || echo "  Port mapping not found"
echo ""

# Test from outside (if domain is set)
echo "10. Testing external connectivity:"
if command -v curl &> /dev/null; then
    # Try localhost
    echo "  Testing http://localhost:"
    curl -s -o /dev/null -w "  Status: %{http_code}, Time: %{time_total}s\n" http://localhost 2>&1 || echo "  Failed to connect"
    
    # Try 127.0.0.1
    echo "  Testing http://127.0.0.1:"
    curl -s -o /dev/null -w "  Status: %{http_code}, Time: %{time_total}s\n" http://127.0.0.1 2>&1 || echo "  Failed to connect"
    
    # Try server IP if we can determine it
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != "127.0.0.1" ]; then
        echo "  Testing http://$SERVER_IP:"
        curl -s -o /dev/null -w "  Status: %{http_code}, Time: %{time_total}s\n" http://$SERVER_IP 2>&1 || echo "  Failed to connect"
    fi
fi
echo ""

# Check firewall
echo "11. Firewall check (if applicable):"
if command -v ufw &> /dev/null; then
    echo "  UFW status:"
    sudo ufw status | head -5 || echo "  Cannot check UFW"
elif command -v firewall-cmd &> /dev/null; then
    echo "  Firewalld status:"
    sudo firewall-cmd --list-ports 2>/dev/null || echo "  Cannot check firewalld"
else
    echo "  No common firewall tool found (ufw/firewalld)"
    echo "  Check your system's firewall settings manually"
fi
echo ""

# Summary and recommendations
echo "=== Summary ==="
echo ""
if [ "$WEB_RUNNING" = "yes" ] && [ "$NGINX_RUNNING" = "yes" ]; then
    echo "✓ Both containers are running"
    
    # Test the full chain
    if docker compose exec -T nginx wget -q -O- http://web:8000/ > /dev/null 2>&1; then
        echo "✓ Nginx can reach web container"
        echo ""
        echo "If website is still not reachable, check:"
        echo "1. Firewall settings - ensure ports 80 and 443 are open"
        echo "2. DNS settings - ensure domain points to this server"
        echo "3. Server network - ensure server is accessible from internet"
        echo "4. Check: curl http://localhost (should work from server)"
        echo "5. Check: curl http://YOUR_SERVER_IP (should work from outside)"
    else
        echo "✗ Nginx cannot reach web container"
        echo ""
        echo "Fix:"
        echo "1. Check Docker network: docker network inspect website_app-network"
        echo "2. Restart containers: docker compose restart"
        echo "3. Check web container logs: docker compose logs web"
    fi
else
    echo "✗ Containers are not running properly"
    echo "  Start with: docker compose up -d"
fi

