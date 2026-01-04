#!/bin/bash
set -e

echo "=== DEBUGGING DEPLOYMENT ==="

# 1. Check if containers are running
echo "1. Checking containers..."
docker ps

# 2. Check nginx configuration
echo "2. Checking nginx configuration..."
docker exec nginx nginx -t

# 3. Check nginx logs
echo "3. Checking nginx error logs..."
docker exec nginx tail -50 /var/log/nginx/error.log || echo "No error log found"

# 4. Check if web service is reachable from nginx
echo "4. Testing connectivity to web service..."
docker exec nginx ping -c 2 web || echo "Cannot ping web service"

# 5. Check DNS resolution in nginx
echo "5. Testing DNS resolution in nginx..."
docker exec nginx nslookup web || docker exec nginx cat /etc/resolv.conf

# 6. Check if ports are exposed
echo "6. Checking port exposure..."
sudo netstat -tulpn | grep ':80\|:443' || echo "No ports found"

# 7. Check firewall
echo "7. Checking firewall..."
sudo ufw status

# 8. Check certbot certificates
echo "8. Checking SSL certificates..."
docker exec nginx ls -la /etc/letsencrypt/live/ || echo "No certificates found"

# 9. Simple curl test from nginx to web
echo "9. Testing internal connectivity..."
docker exec nginx curl -I http://web:8000 || echo "Cannot connect to web:8000"

echo "=== DEBUG COMPLETE ==="