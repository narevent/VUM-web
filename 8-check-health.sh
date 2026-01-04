#!/bin/bash
# Health Check Script
# Diagnose issues with your deployment

echo "=== Django Application Health Check ==="
echo ""

# Check if containers are running
echo "1. Container Status"
echo "-------------------"
docker compose ps
echo ""

# Check Django container
echo "2. Django Container Health"
echo "---------------------------"
if docker compose ps | grep -q "django_app.*Up"; then
    echo "✓ Django container is running"
    
    # Check if Django is responding
    if docker compose exec -T web curl -f -s http://localhost:8000 > /dev/null 2>&1; then
        echo "✓ Django is responding on port 8000"
    else
        echo "✗ Django is NOT responding on port 8000"
    fi
else
    echo "✗ Django container is NOT running"
fi
echo ""

# Check nginx container
echo "3. Nginx Container Health"
echo "--------------------------"
if docker compose ps | grep -q "nginx.*Up"; then
    echo "✓ Nginx container is running"
    
    # Check nginx config
    if docker compose exec nginx nginx -t 2>&1 | grep -q "successful"; then
        echo "✓ Nginx configuration is valid"
    else
        echo "✗ Nginx configuration has errors:"
        docker compose exec nginx nginx -t 2>&1
    fi
else
    echo "✗ Nginx container is NOT running"
fi
echo ""

# Check ports
echo "4. Port Accessibility"
echo "---------------------"
# Check port 80
if curl -f -s -o /dev/null http://localhost:80; then
    echo "✓ Port 80 (HTTP) is accessible"
else
    echo "✗ Port 80 (HTTP) is NOT accessible"
fi

# Check port 443
if curl -f -s -k -o /dev/null https://localhost:443 2>/dev/null; then
    echo "✓ Port 443 (HTTPS) is accessible"
else
    echo "⚠ Port 443 (HTTPS) is not accessible (normal if HTTPS not setup yet)"
fi
echo ""

# Check environment configuration
echo "5. Environment Configuration"
echo "----------------------------"
if [ -f ".env.production" ]; then
    echo "✓ .env.production exists"
    
    # Check key variables
    if grep -q "^SECRET_KEY=" .env.production; then
        echo "✓ SECRET_KEY is set"
    else
        echo "✗ SECRET_KEY is missing"
    fi
    
    if grep -q "^DEBUG=" .env.production; then
        DEBUG_VALUE=$(grep "^DEBUG=" .env.production | cut -d'=' -f2)
        echo "  DEBUG=$DEBUG_VALUE"
    fi
    
    if grep -q "^SECURE_SSL_REDIRECT=" .env.production; then
        SSL_VALUE=$(grep "^SECURE_SSL_REDIRECT=" .env.production | cut -d'=' -f2)
        echo "  SECURE_SSL_REDIRECT=$SSL_VALUE"
    fi
    
    if grep -q "^ALLOWED_HOSTS=" .env.production; then
        HOSTS_VALUE=$(grep "^ALLOWED_HOSTS=" .env.production | cut -d'=' -f2)
        echo "  ALLOWED_HOSTS=$HOSTS_VALUE"
    fi
else
    echo "✗ .env.production does not exist"
fi
echo ""

# Check nginx configuration
echo "6. Nginx Configuration"
echo "----------------------"
if [ -f "nginx/conf.d/app.conf" ]; then
    echo "✓ nginx/conf.d/app.conf exists"
    
    if grep -q "listen 443" nginx/conf.d/app.conf; then
        echo "  HTTPS configuration is active"
    else
        echo "  HTTP-only configuration is active"
    fi
else
    echo "✗ nginx/conf.d/app.conf does not exist"
fi
echo ""

# Check SSL certificates
echo "7. SSL Certificates"
echo "-------------------"
if docker compose exec nginx ls /etc/letsencrypt/live/vumgames.com/fullchain.pem 2>/dev/null; then
    echo "✓ SSL certificates are installed"
    
    # Check expiry
    EXPIRY=$(docker compose exec nginx openssl x509 -enddate -noout -in /etc/letsencrypt/live/vumgames.com/fullchain.pem 2>/dev/null | cut -d'=' -f2)
    if [ -n "$EXPIRY" ]; then
        echo "  Expires: $EXPIRY"
    fi
else
    echo "⚠ SSL certificates not found (normal if HTTPS not setup yet)"
fi
echo ""

# Recent logs
echo "8. Recent Django Logs (last 20 lines)"
echo "--------------------------------------"
docker compose logs --tail=20 web
echo ""

echo "9. Recent Nginx Logs (last 20 lines)"
echo "-------------------------------------"
docker compose logs --tail=20 nginx
echo ""

# Network test
echo "10. Network Connectivity"
echo "------------------------"
if docker compose exec web ping -c 1 web 2>/dev/null | grep -q "1 packets transmitted, 1 received"; then
    echo "✓ Web container can reach itself"
else
    echo "✗ Network issues detected"
fi

if docker compose exec nginx ping -c 1 web 2>/dev/null | grep -q "1 packets transmitted, 1 received"; then
    echo "✓ Nginx can reach web container"
else
    echo "✗ Nginx cannot reach web container"
fi
echo ""

# Summary
echo "=== Health Check Complete ==="
echo ""
echo "Common Issues & Solutions:"
echo ""
echo "If Django not responding:"
echo "  • Check logs: docker compose logs web"
echo "  • Restart: docker compose restart web"
echo "  • Check DB: docker compose exec web python manage.py check"
echo ""
echo "If Nginx not responding:"
echo "  • Check config: docker compose exec nginx nginx -t"
echo "  • Check logs: docker compose logs nginx"
echo "  • Restart: docker compose restart nginx"
echo ""
echo "If getting 502 Bad Gateway:"
echo "  • Django may be down or starting"
echo "  • Check: docker compose exec web curl http://localhost:8000"
echo ""
echo "If getting 301 redirects:"
echo "  • Check SECURE_SSL_REDIRECT in .env.production"
echo "  • Should be False for HTTP, True for HTTPS"