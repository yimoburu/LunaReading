#!/bin/bash
# Comprehensive fix for 502 Bad Gateway - ensures BACKEND_URL is properly set and template is processed

REGION=${1:-"us-central1"}

echo "🔧 Comprehensive Fix for 502 Bad Gateway"
echo "========================================"
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

echo "Diagnosis:"
echo "  - Health check works (static files served directly)"
echo "  - API proxy fails with 502 (nginx can't reach backend)"
echo "  - This means BACKEND_URL is not substituted in nginx config"
echo ""

echo "Step 1: Checking current BACKEND_URL setting..."
CURRENT_ENV=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)
# Parse JSON-like format: {'name': 'BACKEND_URL', 'value': 'https://...'}
CURRENT_BACKEND=$(echo "$CURRENT_ENV" | sed -n "s/.*'name'[[:space:]]*:[[:space:]]*'BACKEND_URL'.*'value'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" || echo "")

if [ -n "$CURRENT_BACKEND" ]; then
    echo "   Current BACKEND_URL: $CURRENT_BACKEND"
    if [ "$CURRENT_BACKEND" != "$BACKEND_URL" ]; then
        echo "   ⚠️  Doesn't match actual backend URL"
    else
        echo "   ✅ Matches actual backend URL"
    fi
else
    echo "   ❌ BACKEND_URL is NOT set"
fi

echo ""
echo "Step 2: Setting BACKEND_URL environment variable..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ BACKEND_URL set to: $BACKEND_URL"
echo ""

echo "Step 3: Rebuilding frontend..."
echo "   (This ensures the Dockerfile with custom entrypoint is used)"
echo "   The new Dockerfile includes docker-entrypoint.sh that sets BACKEND_URL before nginx processes templates"
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

echo "   Building image with custom entrypoint..."
gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-frontend.yaml

echo "✅ Frontend image rebuilt"
echo ""

echo "Step 4: Redeploying frontend with BACKEND_URL..."
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

echo "✅ Frontend redeployed"
echo ""

echo "Step 5: Waiting for container to start and stabilize..."
sleep 15

echo ""
echo "Step 6: Checking startup logs for template processing..."
echo ""
LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1)

echo "   Looking for custom entrypoint output..."
echo "$LOGS" | grep -E "(Nginx Entrypoint|BACKEND_URL=|===)" | tail -5

echo ""
echo "   Template processing:"
echo "$LOGS" | grep -E "(template|nginx|Processing|Verifying)" | tail -5

echo ""
echo "   Errors:"
ERRORS=$(echo "$LOGS" | grep -E "(ERROR|error|failed|502)" | tail -5)
if [ -n "$ERRORS" ]; then
    echo "$ERRORS"
else
    echo "   No errors found"
fi

echo ""
echo "Step 7: Testing proxy..."
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -n "$FRONTEND_URL" ]; then
    echo "   Frontend URL: $FRONTEND_URL"
    echo ""
    
    # Test GET /api/profile (should return 401 if proxy works)
    echo "   Testing GET /api/profile (should return 401 if proxy works)..."
    PROFILE_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/api/profile" 2>/dev/null || echo "000")
    if [ "$PROFILE_CODE" = "401" ] || [ "$PROFILE_CODE" = "403" ]; then
        echo "   ✅ GET proxy works! HTTP $PROFILE_CODE (auth failed, but proxy succeeded)"
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
    elif [ "$REGISTER_CODE" = "502" ]; then
        echo "   ❌ POST proxy still failing: HTTP $REGISTER_CODE"
        echo ""
        echo "   The issue persists. Checking nginx configuration..."
        echo ""
        echo "   Possible causes:"
        echo "   1. Template was not processed (BACKEND_URL not substituted)"
        echo "   2. Custom entrypoint didn't run"
        echo "   3. Template syntax issue"
        echo ""
        echo "   Next steps:"
        echo "   1. Check if custom entrypoint ran: Look for '=== Nginx Entrypoint with BACKEND_URL ===' in logs"
        echo "   2. Check verification script output: Look for '✅ BACKEND_URL was substituted successfully'"
        echo "   3. Run: ./test_startup_script.sh $REGION"
        echo "   4. Check nginx error logs:"
        echo "      gcloud run services logs read lunareading-frontend --region $REGION --limit 50 | grep -E '(error|proxy|upstream)'"
    else
        echo "   ⚠️  POST proxy returned: HTTP $REGISTER_CODE"
    fi
else
    echo "   ⚠️  Could not get frontend URL"
fi

echo ""
echo "📝 Summary:"
echo "  Backend URL: $BACKEND_URL"
echo "  Frontend URL: $FRONTEND_URL"
echo "  BACKEND_URL env var: Set"
echo ""
echo "If still failing, run:"
echo "  ./debug_frontend_backend.sh $REGION"
echo "  ./verify_template_processing.sh $REGION"

