#!/bin/bash
# List all databases in Cloud SQL instance

echo "📋 Listing databases in Cloud SQL instance..."
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

# Extract instance name from connection name
INSTANCE_NAME=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f3)

echo "Instance: $INSTANCE_NAME"
echo "Connection: $CLOUDSQL_INSTANCE_CONNECTION_NAME"
echo ""

# Method 1: Using gcloud (if you have Cloud SQL Admin API access)
echo "Method 1: Using gcloud command..."
echo "-----------------------------------"
gcloud sql databases list --instance="$INSTANCE_NAME" 2>/dev/null

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully listed databases using gcloud"
    echo ""
    echo "To set the database name in .env:"
    echo "  CLOUDSQL_DATABASE=<database-name>"
    exit 0
fi

# Method 2: Using Python script
echo ""
echo "Method 2: Using Python script..."
echo "-----------------------------------"
python3 scripts/list_cloud_sql_databases.py

