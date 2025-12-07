#!/bin/bash
# Test registration endpoint to diagnose issues

set -e

BACKEND_URL=${1:-"http://localhost:5001"}
REGION=${2:-"us-central1"}

echo "🧪 Testing Registration Endpoint"
echo "Backend URL: $BACKEND_URL"
echo ""

# Check if backend is accessible
echo "1. Checking backend health..."
if curl -s -f "$BACKEND_URL/" > /dev/null; then
    echo "   ✅ Backend is accessible"
    curl -s "$BACKEND_URL/" | python3 -m json.tool || echo "   Response received"
else
    echo "   ❌ Backend is not accessible"
    echo "   Make sure the backend is running"
    exit 1
fi
echo ""

# Check database status
echo "2. Checking database connection..."
DB_STATUS=$(curl -s "$BACKEND_URL/api/db-status" || echo '{"status":"error"}')
echo "$DB_STATUS" | python3 -m json.tool || echo "$DB_STATUS"
echo ""

# Test registration
echo "3. Testing registration endpoint..."
TEST_USERNAME="test_$(date +%s)"
TEST_EMAIL="test_${TEST_USERNAME}@example.com"
TEST_PASSWORD="testpass123"
TEST_GRADE=3

REGISTER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$TEST_USERNAME\",
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"grade_level\": $TEST_GRADE
  }")

HTTP_CODE=$(echo "$REGISTER_RESPONSE" | tail -n1)
BODY=$(echo "$REGISTER_RESPONSE" | sed '$d')

echo "   HTTP Status: $HTTP_CODE"
echo "   Response:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" = "201" ]; then
    echo "✅ Registration successful!"
    echo "   Test user created: $TEST_USERNAME"
elif [ "$HTTP_CODE" = "400" ]; then
    echo "⚠️  Registration failed with 400 (Bad Request)"
    echo "   This might mean the user already exists or validation failed"
elif [ "$HTTP_CODE" = "500" ]; then
    echo "❌ Registration failed with 500 (Server Error)"
    echo "   This usually indicates a database connection issue"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Check Cloud Run logs:"
    echo "      gcloud run services logs read lunareading-backend --region $REGION --limit 50"
    echo "   2. Verify Cloud SQL instance is added:"
    echo "      gcloud run services describe lunareading-backend --region $REGION --format='value(spec.template.metadata.annotations)'"
    echo "   3. Run fix script:"
    echo "      ./scripts/fix_cloudsql_connection.sh PROJECT_ID $REGION"
else
    echo "⚠️  Unexpected status code: $HTTP_CODE"
fi
echo ""

