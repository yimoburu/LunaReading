#!/bin/bash
# Fix database initialization issues

echo "🔧 Fixing database initialization..."
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

echo "Current configuration:"
echo "  Instance: $CLOUDSQL_INSTANCE_CONNECTION_NAME"
echo "  Database: $DATABASE"
echo "  User: $CLOUDSQL_USER"
echo ""

# Extract instance name
INSTANCE_NAME=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f3)
PROJECT_ID=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f1)

echo "Step 1: Checking if database exists..."
gcloud sql databases list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" 2>&1 | grep -q "$DATABASE"

if [ $? -eq 0 ]; then
    echo "✅ Database '$DATABASE' exists"
else
    echo "⚠️  Database '$DATABASE' does not exist"
    echo "   Creating database..."
    gcloud sql databases create "$DATABASE" --instance="$INSTANCE_NAME" --project="$PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database '$DATABASE' created"
    else
        echo "❌ Failed to create database"
        exit 1
    fi
fi

echo ""
echo "Step 2: Initializing tables..."
python3 scripts/initialize_database.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database initialization complete!"
    echo ""
    echo "The database '$DATABASE' is now ready to use."
else
    echo ""
    echo "❌ Database initialization failed"
    exit 1
fi

