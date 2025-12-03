#!/bin/bash
# Quick fix: Set BACKEND_URL and rebuild frontend

REGION=${1:-"us-central1"}

echo "🔧 Fixing BACKEND_URL Issue"
echo "==========================="
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

echo "1. Setting BACKEND_URL environment variable..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ BACKEND_URL set"
echo ""

echo "2. Rebuilding frontend (nginx needs to process template with new BACKEND_URL)..."
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
  --timeout 300 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

echo ""
echo "4. Waiting a few seconds for deployment to stabilize..."
sleep 5

echo ""
echo "5. Testing proxy..."
if [ -n "$FRONTEND_URL" ]; then
    PROXY_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FRONTEND_URL/api/register" \
      -H "Content-Type: application/json" \
      -d '{"username":"test'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}' 2>/dev/null || echo "000")
    
    if [ "$PROXY_TEST" = "200" ] || [ "$PROXY_TEST" = "201" ]; then
        echo "   ✅ Proxy test: HTTP $PROXY_TEST - SUCCESS!"
    else
        echo "   ⚠️  Proxy test: HTTP $PROXY_TEST - Still failing"
        echo "   Check logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 20"
    fi
else
    echo "   ⚠️  Could not get frontend URL for testing"
fi

echo ""
echo "✅ Fix complete!"
echo ""
echo "The frontend should now be able to proxy requests to the backend."
echo ""
echo "Configuration:"
echo "  Backend URL: $BACKEND_URL"
echo "  Frontend URL: $FRONTEND_URL"
echo "  BACKEND_URL env var: Set"
echo ""
echo "Test it:"
echo "  ./test_proxy_comparison.sh $REGION"
echo ""
echo "Or test in browser: $FRONTEND_URL"
echo ""
echo "If still getting 502, check:"
echo "  1. Verify BACKEND_URL is set: gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)'"
echo "  2. Check nginx logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 30 | grep -E '(error|proxy|upstream)'"

