#!/bin/bash
# Quick deploy script for backend only
# Usage: ./scripts/deploy_backend_only.sh [PROJECT_ID] [REGION] [CLOUDSQL_INSTANCE]

set -e

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}
CLOUDSQL_INSTANCE=${3:-"lunareading-app:us-central1:free-trial-first-project"}

echo "🚀 Deploying backend to Cloud Run"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Cloud SQL Instance: $CLOUDSQL_INSTANCE"
echo ""

# Set project
gcloud config set project $PROJECT_ID

# Deploy backend
echo "📦 Deploying backend..."
gcloud run deploy lunareading-backend \
  --image gcr.io/$PROJECT_ID/lunareading-backend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --add-cloudsql-instances $CLOUDSQL_INSTANCE

echo ""
echo "✅ Backend deployed successfully!"
echo ""
echo "📋 Service URL:"
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format 'value(status.url)')
echo "   $BACKEND_URL"
echo ""
echo "💡 Note: Make sure environment variables are set:"
echo "   ./scripts/update_cloud_run_env.py lunareading-backend $REGION $PROJECT_ID"
