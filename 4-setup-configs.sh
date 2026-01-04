#!/bin/bash
# Setup Configuration Files
# Creates HTTP and HTTPS nginx configs

set -e

echo "=== Setting up Configuration Files ==="

# Create HTTP-only config
echo "Creating HTTP-only configuration..."
cat > nginx/conf.d/app-http.conf << 'EOF'
# HTTP server - for initial setup
server {
    listen 80;
    listen [::]:80;
    server_name vumgames.com www.vumgames.com;

    client_max_body_size 100M;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
        
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location /static/ {
        alias /app/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /app/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}

# Catch-all for IP/other domains
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }
}
EOF

echo "✓ HTTP configuration created"

# Create HTTPS config template
echo "Creating HTTPS configuration template..."
cat > nginx/conf.d/app-https.conf << 'EOF'
# HTTP - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name vumgames.com www.vumgames.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - main configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name vumgames.com www.vumgames.com;

    ssl_certificate /etc/letsencrypt/live/vumgames.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vumgames.com/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;

    client_max_body_size 100M;

    location / {
        proxy_pass http://web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
        
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location /static/ {
        alias /app/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /app/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}

# Catch-all for IP/other domains on HTTPS
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    ssl_certificate /etc/letsencrypt/live/vumgames.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vumgames.com/privkey.pem;

    return 444;
}
EOF

echo "✓ HTTPS configuration template created"

# Make sure SECURE_SSL_REDIRECT is False for initial setup
echo ""
echo "Checking .env.production..."
if grep -q "^SECURE_SSL_REDIRECT=" .env.production; then
    sed -i 's/^SECURE_SSL_REDIRECT=.*/SECURE_SSL_REDIRECT=False/' .env.production
    echo "✓ Set SECURE_SSL_REDIRECT=False for HTTP setup"
else
    echo "SECURE_SSL_REDIRECT=False" >> .env.production
    echo "✓ Added SECURE_SSL_REDIRECT=False"
fi

# Make sure ALLOWED_HOSTS includes localhost
if grep -q "^ALLOWED_HOSTS=" .env.production; then
    if ! grep "^ALLOWED_HOSTS=" .env.production | grep -q "localhost"; then
        echo "⚠ Adding localhost to ALLOWED_HOSTS"
        sed -i 's/^ALLOWED_HOSTS=\(.*\)/ALLOWED_HOSTS=\1,localhost,127.0.0.1/' .env.production
    fi
fi

echo ""
echo "=== Configuration Setup Complete ==="
echo ""
echo "Created files:"
echo "  ✓ nginx/conf.d/app-http.conf  (for HTTP)"
echo "  ✓ nginx/conf.d/app-https.conf (for HTTPS - will be used after SSL setup)"
echo ""
echo "Next step: ./5-start-app.sh"