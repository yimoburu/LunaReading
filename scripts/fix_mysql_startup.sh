#!/bin/bash
# Fix Cloud Run startup issues after MySQL migration

REGION=${1:-"us-central1"}
PROJECT_ID=${2:-$(gcloud config get-value project 2>/dev/null)}

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not specified"
    echo "Usage: $0 [REGION] [PROJECT_ID]"
    exit 1
fi

echo "🔧 Fixing Cloud Run Startup Issues"
echo "==================================="
echo ""

echo "The container is failing to start. Common causes:"
echo "  1. Missing MySQL dependencies (pymysql, sqlalchemy)"
echo "  2. Database connection errors"
echo "  3. Cloud SQL instance not properly connected"
echo ""

echo "Step 1: Checking current service status..."
echo ""
gcloud run services describe lunareading-backend --region $REGION --format="value(status.conditions[0].message)" 2>&1 | head -5

echo ""
echo "Step 2: Rebuilding backend with MySQL dependencies..."
echo ""

# Create temporary cloudbuild config
cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '-t'
    - 'gcr.io/$PROJECT_ID/lunareading-backend:latest'
    - '-f'
    - 'Dockerfile.backend'
    - '.'
images:
- 'gcr.io/$PROJECT_ID/lunareading-backend:latest'
EOF

echo "   Building image with updated requirements.txt..."
gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=$REGION
rm /tmp/cloudbuild-backend.yaml

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Backend rebuilt with MySQL dependencies"
echo ""

echo "Step 3: Checking Cloud SQL connection..."
echo ""

# Get connection info
if [ -f .cloudsql_user_password ]; then
    CONNECTION_NAME=$(grep "^CONNECTION_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2)
    DB_USER=$(grep "^DB_USER=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading_user")
    DATABASE_NAME=$(grep "^DATABASE_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading")
    DB_PASSWORD=$(grep -v -E "^(DB_USER|DATABASE_NAME|CONNECTION_NAME)=" .cloudsql_user_password | head -1)
    
    if [ -n "$CONNECTION_NAME" ] && [ -n "$DB_PASSWORD" ]; then
        CONNECTION_STRING="mysql+pymysql://${DB_USER}:${DB_PASSWORD}@/${DATABASE_NAME}?unix_socket=/cloudsql/${CONNECTION_NAME}"
        
        echo "   Connection Name: $CONNECTION_NAME"
        echo "   Database: $DATABASE_NAME"
        echo ""
        
        echo "Step 4: Updating Cloud Run service..."
        echo ""
        
        gcloud run services update lunareading-backend \
            --region $REGION \
            --image gcr.io/$PROJECT_ID/lunareading-backend:latest \
            --add-cloudsql-instances $CONNECTION_NAME \
            --update-env-vars "SQLALCHEMY_DATABASE_URI=${CONNECTION_STRING}" \
            --project=$PROJECT_ID
        
        echo ""
        echo "✅ Service updated"
    else
        echo "⚠️  Could not read connection info from .cloudsql_user_password"
        echo "   Run setup_cloud_sql.sh first"
    fi
else
    echo "⚠️  .cloudsql_user_password file not found"
    echo "   Run setup_cloud_sql.sh first"
fi

echo ""
echo "Step 5: Waiting for service to start..."
echo ""
sleep 10

echo "Step 6: Checking service status..."
echo ""
gcloud run services describe lunareading-backend --region $REGION --format="value(status.url)" 2>&1

echo ""
echo "Step 7: Checking recent logs..."
echo ""
gcloud run services logs read lunareading-backend --region $REGION --limit 30 2>&1 | tail -20

echo ""
echo "📝 If service still fails:"
echo "   1. Check logs: gcloud run services logs read lunareading-backend --region $REGION --limit 100"
echo "   2. Verify Cloud SQL instance is running"
echo "   3. Check IAM permissions for Cloud SQL Client role"
echo "   4. Verify connection string format"

