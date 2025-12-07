#!/bin/bash
# Quick script to get database name from Cloud SQL

echo "🔍 Finding database name in Cloud SQL..."
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

# Extract instance name from connection name
INSTANCE_NAME=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f3)
PROJECT_ID=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f1)
REGION=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f2)

echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Instance: $INSTANCE_NAME"
echo ""

# List databases using gcloud
echo "📊 Available databases:"
echo "-----------------------------------"
gcloud sql databases list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" 2>&1

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Could not list databases using gcloud"
    echo "   Trying Python script instead..."
    echo ""
    python3 scripts/list_cloud_sql_databases.py
else
    echo ""
    echo "✅ To set database name in .env, use:"
    echo "   CLOUDSQL_DATABASE=<database-name>"
    echo ""
    echo "💡 Common database names:"
    echo "   - lunareading (if you created it)"
    echo "   - Or use one of the databases listed above"
fi

