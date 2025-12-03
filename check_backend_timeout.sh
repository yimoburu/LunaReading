#!/bin/bash
# Check backend timeout configuration and response times

REGION=${1:-"us-central1"}

echo "🔍 Checking Backend Timeout Configuration"
echo "=========================================="
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

# Check backend timeout
echo "1. Backend timeout configuration:"
BACKEND_TIMEOUT=$(gcloud run services describe lunareading-backend --region $REGION --format='value(spec.template.spec.timeoutSeconds)' 2>/dev/null)
if [ -n "$BACKEND_TIMEOUT" ]; then
    echo "   Timeout: ${BACKEND_TIMEOUT}s"
    if [ "$BACKEND_TIMEOUT" -lt 300 ]; then
        echo "   ⚠️  WARNING: Timeout is less than 300s. OpenAI calls may timeout."
        echo "   Increase with: gcloud run services update lunareading-backend --region $REGION --timeout 300"
    else
        echo "   ✅ Timeout is sufficient"
    fi
else
    echo "   ⚠️  Timeout not set (using default)"
fi

echo ""

# Check frontend timeout
echo "2. Frontend timeout configuration:"
FRONTEND_TIMEOUT=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.timeoutSeconds)' 2>/dev/null)
if [ -n "$FRONTEND_TIMEOUT" ]; then
    echo "   Timeout: ${FRONTEND_TIMEOUT}s"
else
    echo "   ⚠️  Timeout not set (using default)"
fi

echo ""

# Test backend response time
echo "3. Testing backend response times..."
echo ""

echo "   Health check:"
START=$(date +%s%N)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BACKEND_URL/" 2>/dev/null || echo "000")
END=$(date +%s%N)
ELAPSED_MS=$(( (END - START) / 1000000 ))
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Health check: HTTP $HTTP_CODE (${ELAPSED_MS}ms)"
else
    echo "   ❌ Health check: HTTP $HTTP_CODE (${ELAPSED_MS}ms)"
fi

echo ""
echo "   Registration (this may take longer due to OpenAI):"
START=$(date +%s%N)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 60 -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}' 2>/dev/null || echo "000")
END=$(date +%s%N)
ELAPSED_MS=$(( (END - START) / 1000000 ))
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "   ✅ Registration: HTTP $HTTP_CODE (${ELAPSED_MS}ms)"
else
    echo "   ⚠️  Registration: HTTP $HTTP_CODE (${ELAPSED_MS}ms)"
fi

echo ""
echo "4. Recent backend logs (checking for slow operations):"
echo ""
gcloud run services logs read lunareading-backend --region $REGION --limit 30 2>&1 | grep -E "(timeout|slow|error|ERROR)" | tail -10 || echo "   No timeout/slow errors found"

echo ""
echo "📝 Recommendations:"
if [ -n "$BACKEND_TIMEOUT" ] && [ "$BACKEND_TIMEOUT" -lt 300 ]; then
    echo "1. Increase backend timeout to 300s:"
    echo "   gcloud run services update lunareading-backend --region $REGION --timeout 300"
fi
echo "2. If OpenAI calls are slow, consider:"
echo "   - Using a faster model (gpt-3.5-turbo instead of gpt-4o)"
echo "   - Reducing the amount of text processed"
echo "   - Adding retry logic for failed requests"

