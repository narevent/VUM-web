#!/bin/bash
# Initial VPS Setup Script for Django Deployment
# Run this script first to install dependencies

set -e  # Exit on any error

echo "=== Starting Initial VPS Setup ==="

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "Installing Docker..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add current user to docker group
sudo usermod -aG docker $USER

# Install Git
echo "Installing Git..."
sudo apt install -y git

# Verify installations
echo "=== Verifying installations ==="
docker --version
docker-compose --version
git --version

echo ""
echo "=== Initial setup complete! ==="
echo "IMPORTANT: Log out and log back in for Docker group changes to take effect"
echo "Then run: 2-deploy-app.sh"