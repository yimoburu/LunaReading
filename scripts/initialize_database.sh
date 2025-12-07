#!/bin/bash
# Initialize LunaReading database - creates database and tables

echo "🔧 Initializing LunaReading database..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ ERROR: .env file not found"
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$CLOUDSQL_INSTANCE_CONNECTION_NAME" ]; then
    echo "❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set in .env"
    exit 1
fi

if [ -z "$CLOUDSQL_USER" ] || [ -z "$CLOUDSQL_PASSWORD" ]; then
    echo "❌ ERROR: CLOUDSQL_USER and CLOUDSQL_PASSWORD must be set in .env"
    exit 1
fi

DATABASE=${CLOUDSQL_DATABASE:-lunareading}

echo "Configuration:"
echo "  Instance: $CLOUDSQL_INSTANCE_CONNECTION_NAME"
echo "  Database: $DATABASE"
echo "  User: $CLOUDSQL_USER"
echo ""

# Run Python initialization script
python3 scripts/initialize_database.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database initialized successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Make sure CLOUDSQL_DATABASE=$DATABASE is set in your .env file"
    echo "  2. Restart your backend server"
else
    echo ""
    echo "❌ Database initialization failed"
    exit 1
fi

