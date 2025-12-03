#!/bin/bash
# Test various backend API endpoints directly

REGION=${1:-"us-central1"}

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "🧪 Testing Backend API Endpoints"
echo "================================="
echo ""
echo "Backend URL: $BACKEND_URL"
echo ""

# Test 1: Health check
echo "1. Testing health endpoint (GET /)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Health check passed (HTTP $HTTP_CODE)"
    curl -s "$BACKEND_URL/" | python3 -m json.tool 2>/dev/null || curl -s "$BACKEND_URL/"
else
    echo "   ❌ Health check failed (HTTP $HTTP_CODE)"
fi
echo ""

# Test 2: Registration
echo "2. Testing registration (POST /api/register)..."
REGISTER_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}')

REGISTER_CODE=$(echo "$REGISTER_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
REGISTER_BODY=$(echo "$REGISTER_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')

if [ "$REGISTER_CODE" = "200" ] || [ "$REGISTER_CODE" = "201" ]; then
    echo "   ✅ Registration successful (HTTP $REGISTER_CODE)"
    echo "$REGISTER_BODY" | python3 -m json.tool 2>/dev/null | head -10
else
    echo "   ⚠️  Registration returned HTTP $REGISTER_CODE"
    echo "$REGISTER_BODY" | head -5
fi
echo ""

# Test 3: Login (if you have credentials)
echo "3. Testing login (POST /api/login)..."
read -p "   Enter username (or press Enter to skip): " USERNAME
if [ -n "$USERNAME" ]; then
    read -sp "   Enter password: " PASSWORD
    echo ""
    
    LOGIN_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BACKEND_URL/api/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
    
    LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
    
    if [ "$LOGIN_CODE" = "200" ]; then
        echo "   ✅ Login successful (HTTP $LOGIN_CODE)"
        TOKEN=$(echo "$LOGIN_BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)
        if [ -n "$TOKEN" ]; then
            echo "   Token received: ${TOKEN:0:30}..."
            echo ""
            
            # Test 4: Profile with token
            echo "4. Testing profile endpoint (GET /api/profile) with token..."
            PROFILE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET "$BACKEND_URL/api/profile" \
              -H "Authorization: Bearer $TOKEN")
            
            PROFILE_CODE=$(echo "$PROFILE_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
            PROFILE_BODY=$(echo "$PROFILE_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
            
            if [ "$PROFILE_CODE" = "200" ]; then
                echo "   ✅ Profile retrieved (HTTP $PROFILE_CODE)"
                echo "$PROFILE_BODY" | python3 -m json.tool 2>/dev/null | head -15
            else
                echo "   ❌ Profile failed (HTTP $PROFILE_CODE)"
                echo "$PROFILE_BODY" | head -5
            fi
        fi
    else
        echo "   ❌ Login failed (HTTP $LOGIN_CODE)"
        echo "$LOGIN_BODY" | head -5
    fi
else
    echo "   ⏭️  Skipped (no username provided)"
fi

echo ""
echo "✅ Testing complete!"
echo ""
echo "Quick test commands:"
echo "  # Health check"
echo "  curl $BACKEND_URL/"
echo ""
echo "  # Login"
echo "  curl -X POST $BACKEND_URL/api/login -H 'Content-Type: application/json' -d '{\"username\":\"user\",\"password\":\"pass\"}'"
echo ""
echo "  # Profile (with token)"
echo "  curl -H 'Authorization: Bearer YOUR_TOKEN' $BACKEND_URL/api/profile"

