#!/bin/bash
# Quick rebuild and redeploy with fixed nginx template

REGION=${1:-"us-central1"}

echo "🔧 Rebuilding Frontend with Fixed Configuration"
echo "================================================"
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

echo "Step 1: Setting BACKEND_URL environment variable..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ BACKEND_URL set"
echo ""

echo "Step 2: Rebuilding frontend with custom entrypoint..."
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

echo "   Building image (this may take a few minutes)..."
gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION
rm /tmp/cloudbuild-frontend.yaml

echo ""
echo "✅ Frontend image rebuilt"
echo ""

echo "Step 3: Redeploying frontend..."
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

echo "Step 4: Waiting for container to start..."
sleep 15

echo ""
echo "Step 5: Checking logs for template processing..."
echo ""
LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1)

echo "   Custom entrypoint:"
echo "$LOGS" | grep -E "(Nginx Entrypoint|BACKEND_URL=)" | tail -5

echo ""
echo "   Template verification:"
echo "$LOGS" | grep -E "(Verifying|substituted|proxy_pass)" | tail -5

echo ""
echo "Step 6: Testing proxy..."
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -n "$FRONTEND_URL" ]; then
    echo "   Testing GET /api/profile..."
    PROFILE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/api/profile" 2>/dev/null || echo "000")
    if [ "$PROFILE_CODE" = "401" ] || [ "$PROFILE_CODE" = "403" ]; then
        echo "   ✅ GET proxy works! HTTP $PROFILE_CODE"
    else
        echo "   ❌ GET proxy failed: HTTP $PROFILE_CODE"
    fi
    
    echo ""
    echo "   Testing POST /api/register..."
    TIMESTAMP=$(date +%s)
    REGISTER_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FRONTEND_URL/api/register" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"test${TIMESTAMP}\",\"email\":\"test${TIMESTAMP}@test.com\",\"password\":\"test123\",\"grade_level\":3}" \
      --max-time 30 2>/dev/null || echo "000")
    
    if [ "$REGISTER_CODE" = "200" ] || [ "$REGISTER_CODE" = "201" ]; then
        echo "   ✅ POST proxy works! HTTP $REGISTER_CODE"
        echo ""
        echo "🎉 SUCCESS! The proxy is now working!"
    else
        echo "   ❌ POST proxy failed: HTTP $REGISTER_CODE"
        echo ""
        echo "   Check logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 50"
    fi
fi

echo ""
echo "📝 Summary:"
echo "  Backend URL: $BACKEND_URL"
echo "  Frontend URL: $FRONTEND_URL"
echo ""
echo "If still failing, check:"
echo "  ./check_template_substitution.sh $REGION"

