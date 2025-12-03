#!/bin/bash
# Quick test registration with auto-generated test data

REGION=${1:-"us-central1"}

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "📝 Quick Registration Test"
echo "=========================="
echo ""
echo "Backend URL: $BACKEND_URL"
echo ""

# Generate unique test data
TIMESTAMP=$(date +%s)
USERNAME="testuser${TIMESTAMP}"
EMAIL="test${TIMESTAMP}@example.com"
PASSWORD="test123"
GRADE_LEVEL=3

echo "Using test data:"
echo "  Username: $USERNAME"
echo "  Email: $EMAIL"
echo "  Password: $PASSWORD"
echo "  Grade Level: $GRADE_LEVEL"
echo ""

# Test registration
echo "Sending registration request..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USERNAME\",
    \"email\": \"$EMAIL\",
    \"password\": \"$PASSWORD\",
    \"grade_level\": $GRADE_LEVEL
  }")

# Extract HTTP code and body
HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')

echo ""
echo "Response:"
echo "---------"
echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ Registration successful!"
    echo ""
    echo "Response:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    
    # Extract token
    TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        echo ""
        echo "✅ Access token received!"
        echo ""
        echo "Test login with:"
        echo "  curl -X POST $BACKEND_URL/api/login \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}'"
    fi
else
    echo "❌ Registration failed (HTTP $HTTP_CODE)"
    echo ""
    echo "Response:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
fi

