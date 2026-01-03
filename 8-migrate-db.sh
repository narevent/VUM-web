#!/bin/bash
# Migrate database from old location (db.sqlite3) to new location (db/db.sqlite3)

set -e

echo "=== Migrating Database File ==="
echo ""

# Check if old database exists
if [ -f "db.sqlite3" ]; then
    echo "Found existing db.sqlite3 file"
    
    # Create db directory if it doesn't exist
    mkdir -p db
    
    # Check if new location already has a database
    if [ -f "db/db.sqlite3" ]; then
        echo "⚠ Warning: db/db.sqlite3 already exists"
        read -p "Do you want to backup the existing file and migrate? (y/N): " CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "Migration cancelled"
            exit 0
        fi
        # Backup existing file
        mv db/db.sqlite3 db/db.sqlite3.backup.$(date +%Y%m%d_%H%M%S)
        echo "✓ Backed up existing database"
    fi
    
    # Copy old database to new location
    cp db.sqlite3 db/db.sqlite3
    echo "✓ Copied db.sqlite3 to db/db.sqlite3"
    
    # Optionally backup old file
    read -p "Do you want to keep a backup of the old db.sqlite3? (y/N): " KEEP_BACKUP
    if [ "$KEEP_BACKUP" = "y" ] || [ "$KEEP_BACKUP" = "Y" ]; then
        mv db.sqlite3 db.sqlite3.backup.$(date +%Y%m%d_%H%M%S)
        echo "✓ Backed up old db.sqlite3"
    else
        echo "⚠ You can manually delete db.sqlite3 if you want"
    fi
    
    echo ""
    echo "✓ Database migration complete!"
    echo "  Old location: db.sqlite3"
    echo "  New location: db/db.sqlite3"
else
    echo "No existing db.sqlite3 file found"
    echo "Database will be created automatically on first migration"
    
    # Just ensure the directory exists
    mkdir -p db
    echo "✓ Created db/ directory"
fi

echo ""
echo "You can now start the application with: ./3-start-app.sh"

