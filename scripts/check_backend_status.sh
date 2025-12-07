#!/bin/bash
# Check if backend server is running and get its URL

REGION=${1:-"us-central1"}

echo "🔍 Checking Backend Server Status"
echo "=================================="
echo ""

# Check if backend service exists
echo "1. Checking if backend service exists..."
if gcloud run services describe lunareading-backend --region $REGION --format 'value(metadata.name)' > /dev/null 2>&1; then
    echo "   ✅ Backend service found: lunareading-backend"
else
    echo "   ❌ Backend service 'lunareading-backend' not found"
    echo "   💡 Deploy it with: ./deploy-no-docker.sh PROJECT_ID $REGION"
    exit 1
fi
echo ""

# Get backend URL
echo "2. Getting backend URL..."
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "   ❌ Could not get backend URL"
    exit 1
fi

echo "   ✅ Backend URL: $BACKEND_URL"
echo ""

# Test health endpoint
echo "3. Testing backend health endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Backend is responding (HTTP $HTTP_CODE)"
    echo ""
    echo "   Health check response:"
    curl -s "$BACKEND_URL/" | python3 -m json.tool 2>/dev/null || curl -s "$BACKEND_URL/"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "   ❌ Cannot connect to backend"
    echo "   💡 Check if the service is deployed and accessible"
else
    echo "   ⚠️  Backend returned HTTP $HTTP_CODE"
    echo "   Response:"
    curl -s "$BACKEND_URL/" | head -20
fi
echo ""

# Check database status
echo "4. Checking database connection status..."
DB_STATUS=$(curl -s "$BACKEND_URL/api/db-status" 2>/dev/null || echo '{"status":"error"}')
echo "$DB_STATUS" | python3 -m json.tool 2>/dev/null || echo "$DB_STATUS"
echo ""

# Summary
echo "📋 Summary:"
echo "   Backend URL: $BACKEND_URL"
echo "   Status: $([ "$HTTP_CODE" = "200" ] && echo "✅ Running" || echo "❌ Not responding")"
echo ""
echo "💡 Use this URL in your test script:"
echo "   python3 scripts/test_database_through_backend.py $BACKEND_URL"

