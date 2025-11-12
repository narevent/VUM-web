#!/bin/bash
# Deploy Django App Script
# This script clones/pulls your repo and sets up the application

set -e

echo "=== Django App Deployment Script ==="

# Configuration
read -p "Enter your GitHub repository URL (e.g., https://github.com/username/repo.git): " REPO_URL
read -p "Enter deployment directory name [default: app]: " APP_DIR
APP_DIR=${APP_DIR:-app}

# Clone or pull repository
if [ -d "$APP_DIR" ]; then
    echo "Directory $APP_DIR exists. Pulling latest changes..."
    cd $APP_DIR
    git pull origin main || git pull origin master
    cd ..
else
    echo "Cloning repository..."
    git clone $REPO_URL $APP_DIR
fi

cd $APP_DIR

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo ""
    echo "WARNING: .env.production file not found!"
    echo "Creating template .env.production file..."
    cat > .env.production << 'EOF'
# Django Settings
DEBUG=False
SECRET_KEY=your-secret-key-here-change-this
DJANGO_SETTINGS_MODULE=website.settings.production

# Domain
ALLOWED_HOSTS=vumgames.com,www.vumgames.com

# Database (if using PostgreSQL, otherwise ignore)
# DB_NAME=your_db_name
# DB_USER=your_db_user
# DB_PASSWORD=your_db_password
# DB_HOST=db
# DB_PORT=5432

# Email settings (optional)
# EMAIL_HOST=smtp.gmail.com
# EMAIL_PORT=587
# EMAIL_HOST_USER=your-email@gmail.com
# EMAIL_HOST_PASSWORD=your-password
# EMAIL_USE_TLS=True

# Other settings
# Add your other environment variables here
EOF
    echo ""
    echo "Please edit .env.production with your actual values:"
    echo "  nano .env.production"
    read -p "Press enter when you've finished editing .env.production..."
fi

# Create nginx config directory if it doesn't exist
echo "Setting up nginx configuration..."
mkdir -p nginx/conf.d
mkdir -p nginx/ssl

# Create nginx config (HTTP only for initial setup)
cat > nginx/conf.d/app.conf << 'EOF'
# HTTP - for initial setup and certbot verification
server {
    listen 80;
    listen [::]:80;
    server_name vumgames.com www.vumgames.com;

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

    client_max_body_size 100M;
}
EOF

echo ""
echo "=== Deployment setup complete! ==="
echo "Next steps:"
echo "1. Verify your .env.production file is correct"
echo "2. Run: 3-start-app.sh (starts app without HTTPS)"
echo "3. Run: 4-setup-https.sh (configures SSL certificates)"