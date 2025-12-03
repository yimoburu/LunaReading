#!/bin/bash
# Fix 504 Gateway Timeout error

REGION=${1:-"us-central1"}

echo "🔧 Fixing 504 Gateway Timeout Error"
echo "===================================="
echo ""

echo "A 504 error means nginx is waiting too long for the backend to respond."
echo "This can happen when:"
echo "  1. Backend is slow (e.g., OpenAI API calls)"
echo "  2. Nginx timeout is too short"
echo "  3. Backend is not responding"
echo ""

# Check backend status
echo "1. Checking backend status..."
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "   ❌ Backend service not found!"
    exit 1
fi

echo "   Backend URL: $BACKEND_URL"

# Test backend response time
echo ""
echo "2. Testing backend response time..."
START_TIME=$(date +%s)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BACKEND_URL/" 2>/dev/null || echo "000")
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Backend is responding (HTTP $HTTP_CODE) in ${ELAPSED}s"
else
    echo "   ⚠️  Backend returned HTTP $HTTP_CODE (took ${ELAPSED}s)"
    echo "   Check backend logs: gcloud run services logs read lunareading-backend --region $REGION --limit 50"
fi

echo ""
echo "3. Rebuilding frontend with increased timeouts..."
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

echo "4. Redeploying frontend..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --timeout 300 \
  --quiet

echo ""
echo "✅ Frontend redeployed with increased timeouts!"
echo ""
echo "Nginx timeouts updated:"
echo "  - proxy_connect_timeout: 60s"
echo "  - proxy_send_timeout: 300s"
echo "  - proxy_read_timeout: 300s"
echo "  - send_timeout: 300s"
echo ""
echo "Cloud Run timeout: 300s"
echo ""
echo "If you still get 504 errors:"
echo "  1. Check backend logs for slow operations:"
echo "     gcloud run services logs read lunareading-backend --region $REGION --limit 50"
echo ""
echo "  2. Check if backend timeout is sufficient:"
echo "     gcloud run services describe lunareading-backend --region $REGION --format='value(spec.template.spec.timeoutSeconds)'"
echo ""
echo "  3. Consider increasing backend timeout if OpenAI calls are slow:"
echo "     gcloud run services update lunareading-backend --region $REGION --timeout 300"

