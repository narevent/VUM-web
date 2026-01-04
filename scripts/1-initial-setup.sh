#!/bin/bash
set -e

sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ufw

curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable
sudo ufw logging off

echo "Logout & login, then run 2-first-deploy.sh"
