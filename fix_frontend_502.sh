#!/bin/bash
# Fix frontend 502 error by configuring nginx proxy correctly

REGION=${1:-"us-central1"}

echo "🔧 Fixing Frontend 502 Error"
echo "============================="
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    echo "   Deploy backend first: ./deploy-no-docker.sh lunareading-app $REGION"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

# Get frontend URL
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$FRONTEND_URL" ]; then
    echo "❌ Frontend service not found!"
    echo "   Deploy frontend first: ./deploy-no-docker.sh lunareading-app $REGION"
    exit 1
fi

echo "Frontend URL: $FRONTEND_URL"
echo ""

echo "1. Setting BACKEND_URL environment variable in frontend service..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --update-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ Environment variable set"
echo ""

echo "2. Rebuilding frontend with updated nginx configuration..."
cat > /tmp/cloudbuild-frontend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '--build-arg'
    - 'REACT_APP_API_URL='
    - '-t'
    - 'gcr.io/lunareading-app/lunareading-frontend:latest'
    - '-f'
    - 'Dockerfile.frontend'
    - '.'
images:
- 'gcr.io/lunareading-app/lunareading-frontend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-frontend.yaml

echo "✅ Frontend rebuilt"
echo ""

echo "3. Redeploying frontend with BACKEND_URL..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo ""
echo "✅ Frontend redeployed!"
echo ""
echo "Configuration:"
echo "  - Frontend URL: $FRONTEND_URL"
echo "  - Backend URL: $BACKEND_URL"
echo "  - Nginx will proxy /api/* requests to: $BACKEND_URL"
echo ""
echo "Test the frontend at: $FRONTEND_URL"
echo ""
echo "If still getting 502, check:"
echo "  - Frontend logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 50"
echo "  - Backend logs: gcloud run services logs read lunareading-backend --region $REGION --limit 50"
echo "  - Browser console (F12) for API errors"

