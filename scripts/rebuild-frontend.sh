#!/bin/bash
# Rebuild frontend with updated configuration

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🏗️  Rebuilding Frontend"
echo "========================"
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend not found. Deploy backend first."
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

# Create cloudbuild config with backend URL
cat > /tmp/cloudbuild-frontend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '--build-arg'
    - 'REACT_APP_API_URL='
    - '-t'
    - 'gcr.io/$PROJECT_ID/lunareading-frontend:latest'
    - '-f'
    - 'Dockerfile.frontend'
    - '.'
images:
- 'gcr.io/$PROJECT_ID/lunareading-frontend:latest'
EOF

echo "Building frontend (using relative URLs for nginx proxy)..."
gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION --quiet

echo ""
echo "Deploying frontend..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/$PROJECT_ID/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --update-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

rm /tmp/cloudbuild-frontend.yaml

echo ""
echo "✅ Frontend rebuilt and deployed!"
echo ""
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)')
echo "Frontend URL: $FRONTEND_URL"
echo ""
echo "The frontend now uses relative URLs (/api/...) which nginx will proxy to: $BACKEND_URL"

