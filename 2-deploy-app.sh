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

echo ""
echo "=== Deployment setup complete! ==="
echo "Next steps:"
echo "1. Verify your .env.production file is correct"
echo "2. Verify your nginx/conf.d/app.conf file is correct"
echo "2. Run: 3-start-app.sh (starts app without HTTPS)"
echo "3. Run: 4-setup-https.sh (configures SSL certificates)"