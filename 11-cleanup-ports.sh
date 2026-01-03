#!/bin/bash
# Cleanup script to free port 8000 and remove stuck containers

set +e

echo "=== Cleaning Up Port 8000 and Containers ==="
echo ""

# Stop all containers
echo "1. Stopping all containers..."
docker compose down 2>/dev/null || true
docker compose kill 2>/dev/null || true

# Wait for ports to be released
echo "2. Waiting for ports to be released..."
sleep 5

# Remove containers
echo "3. Removing containers..."
docker compose rm -f 2>/dev/null || true

# Check if port 8000 is in use on host (if running directly)
echo "4. Checking host port 8000..."
if command -v lsof &> /dev/null; then
    if lsof -i :8000 &> /dev/null; then
        echo "⚠ Port 8000 is in use on host"
        echo "  Processes using port 8000:"
        lsof -i :8000
        read -p "Kill these processes? (y/N): " KILL
        if [ "$KILL" = "y" ] || [ "$KILL" = "Y" ]; then
            lsof -ti :8000 | xargs kill -9 2>/dev/null || true
            echo "✓ Killed processes on port 8000"
        fi
    else
        echo "✓ Port 8000 is free on host"
    fi
fi

# Clean up Docker networks
echo "5. Cleaning up Docker networks..."
docker network prune -f 2>/dev/null || true

# Check for any stuck containers
echo "6. Checking for stuck containers..."
STUCK=$(docker ps -a --filter "name=django_app" --format "{{.ID}}" 2>/dev/null)
if [ -n "$STUCK" ]; then
    echo "⚠ Found stuck containers: $STUCK"
    read -p "Remove them? (y/N): " REMOVE
    if [ "$REMOVE" = "y" ] || [ "$REMOVE" = "Y" ]; then
        docker rm -f $STUCK 2>/dev/null || true
        echo "✓ Removed stuck containers"
    fi
fi

echo ""
echo "=== Cleanup Complete ==="
echo "You can now run: ./3-start-app.sh"

