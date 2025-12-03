#!/bin/bash
# Check frontend configuration and logs

REGION=${1:-"us-central1"}

echo "🔍 Checking Frontend Configuration"
echo "===================================="
echo ""

# Get URLs
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

echo "Backend URL: $BACKEND_URL"
echo "Frontend URL: $FRONTEND_URL"
echo ""

echo "1. Checking environment variables..."
ENV_VARS=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)

if echo "$ENV_VARS" | grep -q "BACKEND_URL"; then
    echo "   ✅ BACKEND_URL is set"
    echo "   $ENV_VARS"
    echo "   Value: $(echo "$ENV_VARS" | grep -o 'BACKEND_URL=[^,]*' | cut -d= -f2)"
else
    echo "   ❌ BACKEND_URL is NOT set!"
    echo "   Set it with:"
    echo "   gcloud run services update lunareading-frontend --region $REGION --update-env-vars \"BACKEND_URL=$BACKEND_URL\""
fi

echo ""
echo "2. Checking frontend logs (last 30 lines)..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 30 2>&1 | tail -20

echo ""
echo "3. Testing backend directly..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Backend is responding (HTTP $HTTP_CODE)"
else
    echo "   ❌ Backend returned HTTP $HTTP_CODE"
fi

echo ""
echo "4. Testing backend API endpoint..."
REGISTER_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123","grade_level":3}' 2>/dev/null || echo "000")
echo "   Registration endpoint returned: HTTP $REGISTER_CODE"

echo ""
echo "📝 Next steps:"
echo "1. If BACKEND_URL is not set, run: ./fix_frontend_502.sh $REGION"
echo "2. If BACKEND_URL is set but still 502, check nginx logs above"
echo "3. Verify nginx template is being processed correctly"

