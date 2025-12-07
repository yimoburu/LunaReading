#!/bin/bash
# Fix Cloud SQL connection for existing Cloud Run deployment
# This script adds the Cloud SQL instance to the service and grants necessary permissions

set -e

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🔧 Fixing Cloud SQL Connection for Cloud Run Service"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found"
    echo "   Please create .env file with CLOUDSQL_INSTANCE_CONNECTION_NAME"
    exit 1
fi

# Extract Cloud SQL instance connection name
CLOUDSQL_INSTANCE=$(grep "^CLOUDSQL_INSTANCE_CONNECTION_NAME=" .env | cut -d'=' -f2- | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

if [ -z "$CLOUDSQL_INSTANCE" ]; then
    echo "❌ CLOUDSQL_INSTANCE_CONNECTION_NAME not found in .env file"
    echo "   Please add it to your .env file:"
    echo "   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance"
    exit 1
fi

echo "✅ Found Cloud SQL instance: $CLOUDSQL_INSTANCE"
echo ""

# Set project
gcloud config set project $PROJECT_ID

# Step 1: Add Cloud SQL instance to Cloud Run service
echo "Step 1: Adding Cloud SQL instance to Cloud Run service..."
if gcloud run services update lunareading-backend \
  --region $REGION \
  --add-cloudsql-instances $CLOUDSQL_INSTANCE \
  --quiet; then
    echo "✅ Cloud SQL instance added to service"
else
    echo "⚠️  Failed to add Cloud SQL instance (may already be added)"
fi
echo ""

# Step 2: Get service account
echo "Step 2: Getting service account..."
SERVICE_ACCOUNT=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format 'value(spec.template.spec.serviceAccountName)' 2>/dev/null || echo "")

if [ -z "$SERVICE_ACCOUNT" ]; then
    # Try to get the default service account
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format 'value(projectNumber)' 2>/dev/null || echo "")
    if [ -n "$PROJECT_NUMBER" ]; then
        SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
        echo "   Using default Compute Engine service account: $SERVICE_ACCOUNT"
    else
        echo "⚠️  Could not determine service account"
        echo "   You may need to grant permissions manually"
        exit 1
    fi
else
    echo "   Service account: $SERVICE_ACCOUNT"
fi
echo ""

# Step 3: Grant Cloud SQL Client role
echo "Step 3: Granting Cloud SQL Client role..."
if gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client" \
  --condition=None \
  --quiet 2>/dev/null; then
    echo "✅ Cloud SQL Client role granted"
else
    echo "⚠️  Could not grant role (may already have permission)"
    echo "   Checking current permissions..."
    gcloud projects get-iam-policy $PROJECT_ID \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT} AND bindings.role:roles/cloudsql.client" \
      --format="table(bindings.role)" 2>/dev/null | grep -q "cloudsql.client" && \
      echo "   ✅ Service account already has Cloud SQL Client role" || \
      echo "   ⚠️  Service account does not have Cloud SQL Client role"
fi
echo ""

# Step 4: Verify environment variables
echo "Step 4: Checking environment variables..."
ENV_VARS=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format 'value(spec.template.spec.containers[0].env)' 2>/dev/null || echo "")

if echo "$ENV_VARS" | grep -q "CLOUDSQL_INSTANCE_CONNECTION_NAME"; then
    echo "✅ CLOUDSQL_INSTANCE_CONNECTION_NAME is set"
else
    echo "⚠️  CLOUDSQL_INSTANCE_CONNECTION_NAME not found in environment variables"
    echo "   Run: ./scripts/update_cloud_run_env.sh lunareading-backend $REGION"
fi
echo ""

# Summary
echo "✅ Fix complete!"
echo ""
echo "📋 Summary:"
echo "   Cloud SQL instance: $CLOUDSQL_INSTANCE"
echo "   Service account: $SERVICE_ACCOUNT"
echo "   Service: lunareading-backend"
echo "   Region: $REGION"
echo ""
echo "💡 Next steps:"
echo "   1. Wait a few seconds for changes to propagate"
echo "   2. Check service logs:"
echo "      gcloud run services logs read lunareading-backend --region $REGION --limit 50"
echo "   3. Test the connection by making a request to your backend"
echo ""

