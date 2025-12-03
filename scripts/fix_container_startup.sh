#!/bin/bash
# Fix container startup failure

REGION=${1:-"us-central1"}

echo "🔧 Fixing Container Startup Failure"
echo "===================================="
echo ""

echo "The container is failing to start. This is usually due to:"
echo "  1. Nginx configuration error"
echo "  2. Missing environment variable causing template processing to fail"
echo "  3. Startup script taking too long"
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

echo "1. Checking recent logs..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 30 2>&1 | tail -20

echo ""
echo "2. Rebuilding frontend with simplified configuration..."
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

echo "3. Deploying with BACKEND_URL set..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --timeout 300 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo ""
echo "✅ Deployment complete!"
echo ""
echo "The container should now start successfully."
echo ""
echo "If it still fails, check logs:"
echo "  gcloud run services logs read lunareading-frontend --region $REGION --limit 50"

