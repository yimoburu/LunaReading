#!/bin/bash
# Test registration request directly to backend

REGION=${1:-"us-central1"}

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "📝 Testing Registration Directly to Backend"
echo "==========================================="
echo ""
echo "Backend URL: $BACKEND_URL"
echo ""

# Get registration data from user
read -p "Enter username: " USERNAME
read -p "Enter email: " EMAIL
read -sp "Enter password: " PASSWORD
echo ""
read -p "Enter grade level (1-6): " GRADE_LEVEL

if [ -z "$USERNAME" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ] || [ -z "$GRADE_LEVEL" ]; then
    echo "❌ All fields are required"
    exit 1
fi

# Validate grade level
if ! [[ "$GRADE_LEVEL" =~ ^[1-6]$ ]]; then
    echo "❌ Grade level must be between 1 and 6"
    exit 1
fi

echo ""
echo "Sending registration request..."
echo ""

# Test registration
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

echo "Response:"
echo "---------"
echo "HTTP Status: $HTTP_CODE"
echo ""
echo "Response Body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"

echo ""
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ Registration successful!"
    
    # Extract token if present
    TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        echo ""
        echo "Access Token: ${TOKEN:0:50}..."
        echo ""
        echo "You can now use this token to test authenticated endpoints:"
        echo "  curl -H \"Authorization: Bearer $TOKEN\" $BACKEND_URL/api/profile"
        echo ""
        echo "Or test login with the same credentials:"
        echo "  curl -X POST $BACKEND_URL/api/login \\"
        echo "    -H \"Content-Type: application/json\" \\"
        echo "    -d '{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}'"
    fi
else
    echo "❌ Registration failed (HTTP $HTTP_CODE)"
    echo ""
    echo "Common issues:"
    echo "  - Username already exists"
    echo "  - Email already exists"
    echo "  - Invalid data format"
    echo "  - Backend error (check logs)"
    echo ""
    echo "Check backend logs:"
    echo "  gcloud run services logs read lunareading-backend --region $REGION --limit 20"
fi

