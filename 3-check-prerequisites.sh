#!/bin/bash
# Check Prerequisites
# Run this first to verify everything is ready

set -e

echo "=== Checking Prerequisites ==="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install Docker: https://docs.docker.com/get-docker/"
    ERRORS=$((ERRORS + 1))
fi

# Check Docker Compose
echo -n "Checking Docker Compose... "
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install Docker Compose: https://docs.docker.com/compose/install/"
    ERRORS=$((ERRORS + 1))
fi

# Check if Docker is running
echo -n "Checking Docker daemon... "
if docker ps &> /dev/null; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo "  Start Docker and try again"
    ERRORS=$((ERRORS + 1))
fi

# Check .env.production
echo -n "Checking .env.production... "
if [ -f ".env.production" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    
    # Check required variables
    REQUIRED_VARS=("SECRET_KEY" "DEBUG" "ALLOWED_HOSTS")
    for VAR in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${VAR}=" .env.production; then
            echo "  ✓ $VAR is set"
        else
            echo -e "  ${YELLOW}⚠ $VAR is missing${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Create .env.production with required variables:"
    echo "    SECRET_KEY=your-secret-key"
    echo "    DEBUG=False"
    echo "    ALLOWED_HOSTS=vumgames.com,www.vumgames.com,localhost"
    echo "    DJANGO_ENVIRONMENT=production"
    echo "    SECURE_SSL_REDIRECT=False"
    ERRORS=$((ERRORS + 1))
fi

# Check nginx directory structure
echo -n "Checking nginx directory... "
if [ -d "nginx" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    if [ -d "nginx/conf.d" ]; then
        echo "  ✓ conf.d directory exists"
    else
        echo -e "  ${YELLOW}⚠ Creating conf.d directory${NC}"
        mkdir -p nginx/conf.d
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Creating nginx directory structure..."
    mkdir -p nginx/conf.d nginx/ssl
    ERRORS=$((ERRORS + 1))
fi

# Check required directories
echo "Checking required directories..."
for DIR in db media; do
    if [ -d "$DIR" ]; then
        echo "  ✓ $DIR exists"
    else
        echo "  ⚠ Creating $DIR"
        mkdir -p "$DIR"
    fi
done

# Check DNS (if online)
echo ""
echo "Checking DNS configuration..."
DOMAIN_IP=$(dig +short vumgames.com 2>/dev/null | tail -n1)
if [ -n "$DOMAIN_IP" ]; then
    echo "  vumgames.com → $DOMAIN_IP"
    echo -e "  ${YELLOW}⚠ Make sure this IP matches your server${NC}"
else
    echo -e "  ${YELLOW}⚠ Could not resolve vumgames.com${NC}"
    echo "  Make sure your domain DNS is configured before running HTTPS setup"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}=== All checks passed! ===${NC}"
    echo "You can now run: ./4-setup-configs.sh"
else
    echo -e "${RED}=== Found $ERRORS issue(s) ===${NC}"
    echo "Please fix the issues above before continuing."
    exit 1
fi