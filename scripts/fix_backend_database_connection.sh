#!/bin/bash
# Fix backend database connection issues
# Ensures Cloud SQL is properly connected and service account has permissions

set -e

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🔧 Fixing Backend Database Connection"
echo "====================================="
echo ""

# Get backend service account
echo "1. Getting backend service account..."
SERVICE_ACCOUNT=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format 'value(spec.template.spec.serviceAccountName)' 2>/dev/null || echo "")

if [ -z "$SERVICE_ACCOUNT" ]; then
    # Use default compute service account
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format 'value(projectNumber)' 2>/dev/null || echo "")
    if [ -n "$PROJECT_NUMBER" ]; then
        SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
        echo "   Using default Compute Engine service account: $SERVICE_ACCOUNT"
    else
        SERVICE_ACCOUNT="${PROJECT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
        echo "   Using project service account: $SERVICE_ACCOUNT"
    fi
else
    echo "   Service account: $SERVICE_ACCOUNT"
fi
echo ""

# Grant Cloud SQL Client role
echo "2. Granting Cloud SQL Client role..."
if gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client" \
  --condition=None \
  --quiet 2>/dev/null; then
    echo "   ✅ Cloud SQL Client role granted"
else
    echo "   ⚠️  Could not grant role (may already have permission)"
fi
echo ""

# Get Cloud SQL instance connection name from environment variable
echo "3. Checking Cloud SQL configuration..."
CLOUDSQL_INSTANCE=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].env)' 2>/dev/null | \
  python3 -c "import sys, re; data=sys.stdin.read(); match=re.search(r\"\{'name':\s*'CLOUDSQL_INSTANCE_CONNECTION_NAME',\s*'value':\s*'([^']+)'\", data); print(match.group(1) if match else '')" || echo "")

if [ -z "$CLOUDSQL_INSTANCE" ]; then
    echo "   ❌ CLOUDSQL_INSTANCE_CONNECTION_NAME environment variable not set"
    echo "   Please set it with:"
    echo "   gcloud run services update lunareading-backend \\"
    echo "     --region $REGION \\"
    echo "     --update-env-vars \"CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance\""
    exit 1
fi

echo "   ✅ CLOUDSQL_INSTANCE_CONNECTION_NAME is set: $CLOUDSQL_INSTANCE"

# Check if Cloud SQL instance is added to the service (via annotations)
CLOUDSQL_ADDED=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format='value(spec.template.metadata.annotations."run.googleapis.com/cloudsql-instances")' 2>/dev/null || echo "")

if [ -z "$CLOUDSQL_ADDED" ]; then
    echo "   ⚠️  Cloud SQL instance not added to backend service annotations"
    echo "   Adding Cloud SQL instance to backend service..."
    if gcloud run services update lunareading-backend \
      --region $REGION \
      --add-cloudsql-instances $CLOUDSQL_INSTANCE \
      --quiet; then
        echo "   ✅ Cloud SQL instance added to service"
    else
        echo "   ❌ Failed to add Cloud SQL instance"
        echo "   This may cause connection issues. The instance must be added via --add-cloudsql-instances"
        exit 1
    fi
else
    if echo "$CLOUDSQL_ADDED" | grep -q "$CLOUDSQL_INSTANCE"; then
        echo "   ✅ Cloud SQL instance is already added to service: $CLOUDSQL_ADDED"
    else
        echo "   ⚠️  Different Cloud SQL instance in annotations: $CLOUDSQL_ADDED"
        echo "   Expected: $CLOUDSQL_INSTANCE"
        echo "   You may need to update the service to use the correct instance"
    fi
fi
echo ""

# Verify environment variables
echo "4. Verifying environment variables..."
ENV_VARS=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].env)' 2>/dev/null || echo "")

REQUIRED_VARS=("CLOUDSQL_INSTANCE_CONNECTION_NAME" "CLOUDSQL_DATABASE" "CLOUDSQL_USER" "CLOUDSQL_PASSWORD")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if echo "$ENV_VARS" | grep -q "$var"; then
        echo "   ✅ $var is set"
    else
        echo "   ❌ $var is missing"
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo ""
    echo "   ⚠️  Missing environment variables: ${MISSING_VARS[*]}"
    echo "   Set them with:"
    echo "   gcloud run services update lunareading-backend \\"
    echo "     --region $REGION \\"
    echo "     --update-env-vars \"VAR1=value1,VAR2=value2\""
fi
echo ""

# Test backend connection
echo "5. Testing backend health..."
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format 'value(status.url)' 2>/dev/null)

if [ -n "$BACKEND_URL" ]; then
    echo "   Backend URL: $BACKEND_URL"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "   ✅ Backend is responding"
        
        # Test database status endpoint
        echo "   Testing database connection..."
        DB_STATUS=$(curl -s "$BACKEND_URL/api/db-status" 2>/dev/null || echo '{"status":"error"}')
        if echo "$DB_STATUS" | grep -q '"status":"connected"'; then
            echo "   ✅ Database connection is working"
        else
            echo "   ⚠️  Database connection may have issues"
            echo "   Response: $DB_STATUS"
        fi
    else
        echo "   ⚠️  Backend returned HTTP $HTTP_CODE"
    fi
else
    echo "   ❌ Could not get backend URL"
fi
echo ""

echo "✅ Fix complete!"
echo ""
echo "📋 Summary:"
echo "   Service Account: $SERVICE_ACCOUNT"
echo "   Cloud SQL Instance: ${CLOUDSQL_INSTANCE:-'Not configured'}"
echo "   Backend URL: ${BACKEND_URL:-'Not available'}"
echo ""
echo "💡 Next steps:"
echo "   1. Check backend logs:"
echo "      gcloud run services logs read lunareading-backend --region $REGION --limit 50"
echo "   2. Test registration:"
echo "      python3 scripts/test_database_through_backend.py $BACKEND_URL"
echo ""

