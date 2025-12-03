#!/bin/bash
# Update Cloud Run service to use Cloud SQL

set -e

REGION=${1:-"us-central1"}
PROJECT_ID=${2:-$(gcloud config get-value project 2>/dev/null)}
INSTANCE_NAME=${3:-"lunareading-db"}

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not specified"
    echo "Usage: $0 [REGION] [PROJECT_ID] [INSTANCE_NAME]"
    exit 1
fi

echo "🔄 Updating Cloud Run service to use Cloud SQL"
echo "=============================================="
echo ""

# Get connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --format='value(connectionName)' 2>/dev/null)

if [ -z "$CONNECTION_NAME" ]; then
    echo "❌ Could not find Cloud SQL instance: $INSTANCE_NAME"
    exit 1
fi

echo "Connection Name: $CONNECTION_NAME"
echo ""

# Get database credentials
if [ ! -f .cloudsql_user_password ]; then
    echo "❌ Database user password file not found (.cloudsql_user_password)"
    echo "   Run setup_cloud_sql.sh first"
    exit 1
fi

DB_USER=$(grep -E "^DB_USER=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading_user")
DATABASE_NAME=$(grep -E "^DATABASE_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading")
DB_PASSWORD=$(grep -v -E "^(DB_USER|DATABASE_NAME|CONNECTION_NAME)=" .cloudsql_user_password | head -1)

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Could not read database password"
    exit 1
fi

# Build connection string
CONNECTION_STRING="mysql+pymysql://${DB_USER}:${DB_PASSWORD}@/${DATABASE_NAME}?unix_socket=/cloudsql/${CONNECTION_NAME}"

echo "Updating backend service..."
gcloud run services update lunareading-backend \
    --region $REGION \
    --add-cloudsql-instances $CONNECTION_NAME \
    --update-env-vars "SQLALCHEMY_DATABASE_URI=${CONNECTION_STRING}" \
    --project=$PROJECT_ID

echo ""
echo "✅ Cloud Run service updated!"
echo ""
echo "The service will now use Cloud SQL MySQL instead of SQLite."
echo ""
echo "⚠️  Note: You may need to restart the service or wait for it to scale to zero"
echo "   and start a new instance for the changes to take effect."

