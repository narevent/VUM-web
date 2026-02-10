#!/bin/bash

echo "================================"
echo "VumGames Logs Viewer"
echo "================================"
echo ""
echo "Select which logs to view:"
echo "1) Gunicorn service logs (systemd)"
echo "2) Gunicorn access logs"
echo "3) Gunicorn error logs"
echo "4) Nginx access logs"
echo "5) Nginx error logs"
echo "6) All logs (tail -f)"
echo ""
read -p "Enter choice [1-6]: " choice

SERVICE_NAME="gunicorn"

case $choice in
    1)
        echo "Viewing Gunicorn service logs (Ctrl+C to exit)..."
        sudo journalctl -u $SERVICE_NAME -f
        ;;
    2)
        echo "Viewing Gunicorn access logs (Ctrl+C to exit)..."
        sudo tail -f /var/www/vumgames/logs/gunicorn-access.log
        ;;
    3)
        echo "Viewing Gunicorn error logs (Ctrl+C to exit)..."
        sudo tail -f /var/www/vumgames/logs/gunicorn-error.log
        ;;
    4)
        echo "Viewing Nginx access logs (Ctrl+C to exit)..."
        sudo tail -f /var/log/nginx/access.log
        ;;
    5)
        echo "Viewing Nginx error logs (Ctrl+C to exit)..."
        sudo tail -f /var/log/nginx/error.log
        ;;
    6)
        echo "Viewing all logs (Ctrl+C to exit)..."
        sudo tail -f /var/www/vumgames/logs/*.log /var/log/nginx/*.log
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac