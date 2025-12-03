#!/bin/bash
# Test login request directly to backend

REGION=${1:-"us-central1"}

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "🔐 Testing Login Directly to Backend"
echo "===================================="
echo ""
echo "Backend URL: $BACKEND_URL"
echo ""

# Get credentials from user
read -p "Enter username: " USERNAME
read -sp "Enter password: " PASSWORD
echo ""

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Username and password are required"
    exit 1
fi

echo ""
echo "Sending login request..."
echo ""

# Test login
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BACKEND_URL/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

# Extract HTTP code and body
HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')

echo "Response:"
echo "---------"
echo "HTTP Status: $HTTP_CODE"
echo ""
echo "Response Body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"

echo ""
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Login successful!"
    
    # Extract token if present
    TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        echo ""
        echo "Access Token: ${TOKEN:0:50}..."
        echo ""
        echo "You can use this token to test authenticated endpoints:"
        echo "  curl -H \"Authorization: Bearer $TOKEN\" $BACKEND_URL/api/profile"
    fi
else
    echo "❌ Login failed (HTTP $HTTP_CODE)"
    echo ""
    echo "Common issues:"
    echo "  - Invalid username or password"
    echo "  - User doesn't exist"
    echo "  - Backend error (check logs)"
fi

