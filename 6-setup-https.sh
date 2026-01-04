#!/bin/bash
# Setup HTTPS with Let's Encrypt
# Run this after your app is working on HTTP

set -e

echo "=== Setting up HTTPS with Let's Encrypt ==="

# Check if app is running
if ! docker compose ps | grep -q "django_app.*Up"; then
    echo "ERROR: Django application is not running!"
    echo "Please run ./3-start-app.sh first"
    exit 1
fi

# Check if HTTP config is active
if [ ! -f "nginx/conf.d/app.conf" ]; then
    echo "ERROR: nginx/conf.d/app.conf not found!"
    exit 1
fi

# Verify DNS is configured
echo ""
echo "Checking DNS configuration..."
DOMAIN_IP=$(dig +short vumgames.com 2>/dev/null | tail -n1)
if [ -z "$DOMAIN_IP" ]; then
    echo "⚠ WARNING: Cannot resolve vumgames.com"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "Aborted. Please configure your DNS first."
        exit 1
    fi
else
    echo "✓ vumgames.com resolves to: $DOMAIN_IP"
    echo ""
    read -p "Is this the correct IP for this server? (y/N): " CORRECT_IP
    if [ "$CORRECT_IP" != "y" ] && [ "$CORRECT_IP" != "Y" ]; then
        echo "Aborted. Please update your DNS to point to this server."
        exit 1
    fi
fi

# Get email for Let's Encrypt
echo ""
read -p "Enter your email for Let's Encrypt notifications: " EMAIL

if [ -z "$EMAIL" ]; then
    echo "ERROR: Email is required"
    exit 1
fi

# Test if certbot can reach the verification directory
echo ""
echo "Testing certbot access..."
docker compose exec nginx sh -c "mkdir -p /var/www/certbot && echo 'test' > /var/www/certbot/test.txt" 2>/dev/null || true

if curl -f -s http://vumgames.com/.well-known/acme-challenge/test.txt 2>/dev/null | grep -q "test"; then
    echo "✓ Certbot verification path is accessible"
else
    echo "⚠ Warning: Cannot verify certbot path accessibility"
    echo "  This might be okay if DNS isn't fully propagated yet"
fi

# Obtain SSL certificate
echo ""
echo "Obtaining SSL certificate from Let's Encrypt..."
echo "This may take a minute..."

docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d vumgames.com \
    -d www.vumgames.com

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to obtain SSL certificate"
    echo ""
    echo "Common issues:"
    echo "1. DNS not pointing to this server"
    echo "2. Firewall blocking port 80"
    echo "3. Another service using port 80"
    echo "4. Domain not accessible from internet"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check DNS: dig vumgames.com"
    echo "  • Check firewall: sudo ufw status"
    echo "  • Check port 80: sudo netstat -tlnp | grep :80"
    echo "  • Test from outside: curl -I http://vumgames.com"
    exit 1
fi

echo ""
echo "✓ SSL certificate obtained successfully!"

# Verify certificate exists in volume
echo ""
echo "Verifying certificate installation..."
if docker compose exec nginx ls /etc/letsencrypt/live/vumgames.com/fullchain.pem 2>/dev/null; then
    echo "✓ Certificate files found"
else
    echo "ERROR: Certificate files not found in nginx container"
    exit 1
fi

# Switch to HTTPS configuration
echo ""
echo "Switching to HTTPS configuration..."
rm -f nginx/conf.d/app.conf
cp nginx/conf.d/app-https.conf nginx/conf.d/app.conf
echo "✓ HTTPS configuration activated"

# Update Django settings to enable HTTPS redirect
echo ""
echo "Enabling HTTPS redirect in Django..."
if grep -q "^SECURE_SSL_REDIRECT=" .env.production; then
    sed -i 's/^SECURE_SSL_REDIRECT=.*/SECURE_SSL_REDIRECT=True/' .env.production
else
    echo "SECURE_SSL_REDIRECT=True" >> .env.production
fi
echo "✓ HTTPS redirect enabled"

# Test nginx configuration
echo ""
echo "Testing nginx configuration..."
if docker compose exec nginx nginx -t; then
    echo "✓ Nginx configuration is valid"
else
    echo "ERROR: Nginx configuration test failed"
    echo "Reverting to HTTP configuration..."
    cp nginx/conf.d/app-http.conf nginx/conf.d/app.conf
    exit 1
fi

# Restart services to apply changes
echo ""
echo "Restarting services..."
docker compose restart web nginx

# Wait for services to stabilize
echo "Waiting for services to restart..."
sleep 15

# Test HTTPS
echo ""
echo "Testing HTTPS..."
SUCCESS=0
for i in {1..5}; do
    echo "Attempt $i/5..."
    if curl -f -s -k -o /dev/null https://localhost:443; then
        echo "✓ HTTPS is working!"
        SUCCESS=1
        break
    fi
    if [ $i -lt 5 ]; then
        sleep 5
    fi
done

echo ""
if [ $SUCCESS -eq 1 ]; then
    echo "=== ✓ HTTPS Setup Complete! ==="
    echo ""
    echo "Your site is now accessible at:"
    echo "  • https://vumgames.com"
    echo "  • https://www.vumgames.com"
    echo ""
    echo "HTTP traffic will automatically redirect to HTTPS."
    echo ""
    echo "SSL certificates will auto-renew via the certbot container."
    echo ""
    echo "Next steps:"
    echo "  • Test your site in a browser"
    echo "  • Check SSL rating: https://www.ssllabs.com/ssltest/"
else
    echo "=== ⚠ HTTPS Setup Completed with Warnings ==="
    echo ""
    echo "HTTPS may not be responding yet. This could be due to:"
    echo "  • Services still starting up"
    echo "  • Firewall blocking port 443"
    echo "  • DNS propagation delay"
    echo ""
    echo "Check logs:"
    echo "  docker compose logs nginx"
    echo "  docker compose logs web"
    echo ""
    echo "Manual test:"
    echo "  curl -I https://vumgames.com"
fi