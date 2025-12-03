#!/bin/bash
# Fix container startup failure - nginx not starting

REGION=${1:-"us-central1"}

echo "🔧 Fixing Container Startup Issue"
echo "=================================="
echo ""

echo "The container is failing to start. This is usually because:"
echo "  1. Nginx configuration syntax error"
echo "  2. Template variables not substituted correctly"
echo "  3. Entrypoint script failing"
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

echo "Step 1: Checking recent logs for errors..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 50 2>&1 | tail -30

echo ""
echo "Step 2: Setting BACKEND_URL environment variable..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ BACKEND_URL set"
echo ""

echo "Step 3: Rebuilding frontend with fixed entrypoint..."
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

echo "   Building image..."
gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION
rm /tmp/cloudbuild-frontend.yaml

echo ""
echo "✅ Frontend rebuilt"
echo ""

echo "Step 4: Redeploying frontend..."
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

echo "Step 5: Waiting for container to start..."
sleep 20

echo ""
echo "Step 6: Checking startup logs..."
echo ""
LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1)

echo "   Entrypoint execution:"
echo "$LOGS" | grep -E "(Nginx Entrypoint|BACKEND_URL=|BACKEND_HOST=)" | tail -5

echo ""
echo "   Template processing:"
echo "$LOGS" | grep -E "(Processing|substituted|Template)" | tail -5

echo ""
echo "   Errors (if any):"
ERRORS=$(echo "$LOGS" | grep -E "(ERROR|error|failed|exit)" | tail -10)
if [ -n "$ERRORS" ]; then
    echo "$ERRORS"
else
    echo "   No errors found"
fi

echo ""
echo "Step 7: Testing service..."
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -n "$FRONTEND_URL" ]; then
    HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/" 2>/dev/null || echo "000")
    if [ "$HEALTH" = "200" ]; then
        echo "   ✅ Service is running! HTTP $HEALTH"
    else
        echo "   ⚠️  Service health: HTTP $HEALTH"
    fi
fi

echo ""
echo "📝 If container still fails to start:"
echo "  1. Check full logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 100"
echo "  2. Verify nginx config syntax is correct"
echo "  3. Check that BACKEND_URL and BACKEND_HOST are being set correctly"

