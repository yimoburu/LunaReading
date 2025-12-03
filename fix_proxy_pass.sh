#!/bin/bash
# Fix proxy_pass configuration issue

REGION=${1:-"us-central1"}

echo "🔧 Fixing Nginx Proxy Configuration"
echo "===================================="
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

echo "The issue: Health check works (static files) but API proxy fails (502)"
echo "This means nginx proxy_pass is misconfigured"
echo ""

echo "1. Setting BACKEND_URL environment variable..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ BACKEND_URL set"
echo ""

echo "2. Rebuilding frontend with fixed configuration..."
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

echo "3. Redeploying frontend..."
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
echo "4. Waiting for container to start..."
sleep 10

echo ""
echo "5. Checking startup logs..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 50 2>&1 | grep -E "(BACKEND_URL|Processing|template|✅|ERROR|proxy_pass)" | tail -10

echo ""
echo "6. Testing proxy..."
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)
if [ -n "$FRONTEND_URL" ]; then
    PROXY_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FRONTEND_URL/api/register" \
      -H "Content-Type: application/json" \
      -d '{"username":"test'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}' 2>/dev/null || echo "000")
    
    if [ "$PROXY_TEST" = "200" ] || [ "$PROXY_TEST" = "201" ]; then
        echo "   ✅ Proxy test: HTTP $PROXY_TEST - SUCCESS!"
    else
        echo "   ⚠️  Proxy test: HTTP $PROXY_TEST - Still failing"
        echo ""
        echo "   Check startup logs for template processing:"
        echo "   ./check_startup_logs.sh $REGION"
    fi
fi

echo ""
echo "📝 Next steps:"
echo "1. Verify template was processed: ./check_startup_logs.sh $REGION"
echo "2. Test proxy: ./test_proxy_comparison.sh $REGION"
echo "3. If still failing, check: ./verify_nginx_proxy.sh $REGION"

