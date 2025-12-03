#!/bin/bash
# Compare direct backend calls vs frontend proxy calls

REGION=${1:-"us-central1"}

BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ] || [ -z "$FRONTEND_URL" ]; then
    echo "❌ Services not found!"
    exit 1
fi

echo "🔬 Comparing Direct vs Proxy Requests"
echo "======================================"
echo ""
echo "Backend: $BACKEND_URL"
echo "Frontend: $FRONTEND_URL"
echo ""

TIMESTAMP=$(date +%s)
USERNAME="testuser${TIMESTAMP}"
EMAIL="test${TIMESTAMP}@test.com"

echo "Test data:"
echo "  Username: $USERNAME"
echo "  Email: $EMAIL"
echo ""

echo "1. Direct backend call:"
echo "   curl -X POST $BACKEND_URL/api/register ..."
echo ""
DIRECT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"email\":\"$EMAIL\",\"password\":\"test123\",\"grade_level\":3}")
DIRECT_CODE=$(echo "$DIRECT_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
DIRECT_BODY=$(echo "$DIRECT_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
echo "   Status: $DIRECT_CODE"
if [ "$DIRECT_CODE" = "200" ] || [ "$DIRECT_CODE" = "201" ]; then
    echo "   ✅ Success"
else
    echo "   ❌ Failed"
    echo "   Response: $(echo "$DIRECT_BODY" | head -2)"
fi

echo ""
echo "2. Through frontend proxy:"
echo "   curl -X POST $FRONTEND_URL/api/register ..."
echo ""
PROXY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$FRONTEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}2\",\"email\":\"test2${TIMESTAMP}@test.com\",\"password\":\"test123\",\"grade_level\":3}")
PROXY_CODE=$(echo "$PROXY_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
PROXY_BODY=$(echo "$PROXY_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
echo "   Status: $PROXY_CODE"
if [ "$PROXY_CODE" = "200" ] || [ "$PROXY_CODE" = "201" ]; then
    echo "   ✅ Success"
else
    echo "   ❌ Failed"
    echo "   Response: $(echo "$PROXY_BODY" | head -5)"
fi

echo ""
echo "3. Difference analysis:"
if [ "$DIRECT_CODE" = "200" ] || [ "$DIRECT_CODE" = "201" ]; then
    if [ "$PROXY_CODE" = "200" ] || [ "$PROXY_CODE" = "201" ]; then
        echo "   ✅ Both work - proxy is functioning correctly"
        echo "   If browser still fails, check:"
        echo "     - Browser console (F12) for JavaScript errors"
        echo "     - Network tab to see actual request URL"
        echo "     - CORS headers in response"
    else
        echo "   ❌ Direct works but proxy fails"
        echo "   Issue: Nginx proxy configuration"
        echo "   Fix: ./fix_frontend_502.sh $REGION"
    fi
else
    echo "   ⚠️  Direct call also failed - backend issue"
    echo "   Check backend logs: gcloud run services logs read lunareading-backend --region $REGION --limit 20"
fi

