#!/bin/bash
# Debug frontend 502 error - check logs and configuration

REGION=${1:-"us-central1"}

echo "🔍 Debugging Frontend 502 Error"
echo "================================"
echo ""

# Get URLs
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

echo "Backend URL: $BACKEND_URL"
echo "Frontend URL: $FRONTEND_URL"
echo ""

echo "1. Checking environment variables in frontend service..."
ENV_OUTPUT=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)
echo "$ENV_OUTPUT" | grep -i backend || echo "   ❌ BACKEND_URL not found in environment variables"

# Try to extract BACKEND_URL value
# Parse JSON-like format: {'name': 'BACKEND_URL', 'value': 'https://...'}
# Extract the value after 'value': ' (handle different spacing)
BACKEND_FROM_ENV=$(echo "$ENV_OUTPUT" | sed -n "s/.*'name'[[:space:]]*:[[:space:]]*'BACKEND_URL'.*'value'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" || echo "")
echo "BACKEND_FROM_ENV: $BACKEND_FROM_ENV"
if [ -n "$BACKEND_FROM_ENV" ]; then
    echo "   ✅ BACKEND_URL found: $BACKEND_FROM_ENV"
    if [ "$BACKEND_FROM_ENV" != "$BACKEND_URL" ]; then
        echo "   ⚠️  WARNING: BACKEND_URL in env ($BACKEND_FROM_ENV) doesn't match actual backend URL ($BACKEND_URL)"
    fi
else
    echo "   ❌ BACKEND_URL not set or empty"
fi

echo ""
echo "2. Checking frontend startup logs (looking for nginx config generation)..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1 | grep -E "(Nginx Config|BACKEND_URL|envsubst|proxy_pass|ERROR)" | tail -20 || echo "   No relevant logs found"

echo ""
echo "3. Checking recent frontend logs (last 50 lines)..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 50 2>&1 | tail -30

echo ""
echo "4. Testing backend directly..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Backend is responding (HTTP $HTTP_CODE)"
else
    echo "   ❌ Backend returned HTTP $HTTP_CODE"
fi

echo ""
echo "5. Testing backend API endpoint..."
REGISTER_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123","grade_level":3}' 2>/dev/null || echo "000")
echo "   Registration endpoint returned: HTTP $REGISTER_CODE"

echo ""
echo "📝 Recommendations:"
if [ -z "$BACKEND_FROM_ENV" ]; then
    echo "1. BACKEND_URL is not set. Run: ./fix_frontend_502.sh $REGION"
elif [ "$BACKEND_FROM_ENV" != "$BACKEND_URL" ]; then
    echo "1. BACKEND_URL is incorrect. Update it:"
    echo "   gcloud run services update lunareading-frontend --region $REGION --set-env-vars \"BACKEND_URL=$BACKEND_URL\""
else
    echo "1. BACKEND_URL is set correctly"
    echo "2. Check if nginx config generation script is running (look for 'Nginx Config Generation' in logs)"
    echo "3. If script isn't running, rebuild frontend: ./fix_frontend_502.sh $REGION"
fi

