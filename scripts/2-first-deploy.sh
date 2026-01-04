#!/bin/bash
set -e

read -p "Git repo URL: " REPO
read -p "Domain name (example.com): " DOMAIN

git clone $REPO app
cd app

sed -i "s/example.com/$DOMAIN/g" docker/nginx/app.conf

docker compose build
docker compose up -d web nginx
