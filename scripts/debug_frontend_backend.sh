#!/bin/bash
# Debug why frontend can't reach backend even though direct calls work

REGION=${1:-"us-central1"}

echo "🔍 Debugging Frontend-Backend Connection"
echo "======================================="
echo ""

# Get URLs
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ] || [ -z "$FRONTEND_URL" ]; then
    echo "❌ Services not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo "Frontend URL: $FRONTEND_URL"
echo ""

# Check environment variables
echo "1. Checking frontend environment variables..."
ENV_VARS=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)

# Parse JSON-like format: {'name': 'BACKEND_URL', 'value': 'https://...'}
# Extract the value after 'value': ' (handle different spacing)
BACKEND_FROM_ENV=$(echo "$ENV_VARS" | sed -n "s/.*'name'[[:space:]]*:[[:space:]]*'BACKEND_URL'.*'value'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" || echo "")

if [ -n "$BACKEND_FROM_ENV" ]; then
    echo "   ✅ BACKEND_URL is set: $BACKEND_FROM_ENV"
    if [ "$BACKEND_FROM_ENV" != "$BACKEND_URL" ]; then
        echo "   ⚠️  WARNING: BACKEND_URL in env doesn't match actual backend URL!"
        echo "   Update with: gcloud run services update lunareading-frontend --region $REGION --set-env-vars \"BACKEND_URL=$BACKEND_URL\""
    fi
else
    echo "   ❌ BACKEND_URL is NOT set!"
    echo "   Set it with: gcloud run services update lunareading-frontend --region $REGION --set-env-vars \"BACKEND_URL=$BACKEND_URL\""
fi

echo ""

# Test direct backend
echo "2. Testing direct backend calls..."
echo ""

echo "   Health check:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Backend health: HTTP $HTTP_CODE"
else
    echo "   ❌ Backend health: HTTP $HTTP_CODE"
fi

echo ""
echo "   Registration (direct):"
REGISTER_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BACKEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}' 2>/dev/null)
REGISTER_CODE=$(echo "$REGISTER_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
if [ "$REGISTER_CODE" = "200" ] || [ "$REGISTER_CODE" = "201" ]; then
    echo "   ✅ Direct registration: HTTP $REGISTER_CODE"
else
    echo "   ❌ Direct registration: HTTP $REGISTER_CODE"
fi

echo ""

# Test through frontend proxy
echo "3. Testing through frontend proxy (nginx)..."
echo ""

echo "   Health check through frontend (GET /):"
echo "   This should work - nginx serves static files directly"
FRONTEND_HEALTH_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}" "$FRONTEND_URL/" 2>/dev/null || echo "000")
FRONTEND_HEALTH=$(echo "$FRONTEND_HEALTH_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
FRONTEND_HEALTH_TIME=$(echo "$FRONTEND_HEALTH_RESPONSE" | grep -o "TIME_TOTAL:[0-9.]*" | cut -d: -f2)
if [ "$FRONTEND_HEALTH" = "200" ]; then
    echo "   ✅ Frontend health: HTTP $FRONTEND_HEALTH (${FRONTEND_HEALTH_TIME}s)"
    echo "   Note: This works because nginx serves static files, not proxying"
else
    echo "   ❌ Frontend health: HTTP $FRONTEND_HEALTH"
fi

echo ""
echo "   Testing backend API through proxy (GET /api/profile - should fail with 401):"
# This tests if /api proxy works at all (even if it returns 401, it means proxy works)
API_TEST_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}" "$FRONTEND_URL/api/profile" 2>/dev/null || echo "000")
API_TEST_CODE=$(echo "$API_TEST_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
API_TEST_TIME=$(echo "$API_TEST_RESPONSE" | grep -o "TIME_TOTAL:[0-9.]*" | cut -d: -f2)
if [ "$API_TEST_CODE" = "401" ] || [ "$API_TEST_CODE" = "403" ]; then
    echo "   ✅ API proxy is working! HTTP $API_TEST_CODE (${API_TEST_TIME}s)"
    echo "   (401/403 is expected - means proxy reached backend but auth failed)"
elif [ "$API_TEST_CODE" = "502" ]; then
    echo "   ❌ API proxy failed: HTTP $API_TEST_CODE (Bad Gateway)"
    echo "   This means nginx can't reach the backend"
elif [ "$API_TEST_CODE" = "504" ]; then
    echo "   ❌ API proxy failed: HTTP $API_TEST_CODE (Gateway Timeout)"
    echo "   This means nginx timed out waiting for backend"
else
    echo "   ⚠️  API proxy returned: HTTP $API_TEST_CODE (${API_TEST_TIME}s)"
fi

echo ""
echo "   Registration through frontend proxy (POST /api/register):"
echo "   This is the failing request - let's see why..."
TIMESTAMP=$(date +%s)
PROXY_REGISTER_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}\nTIME_CONNECT:%{time_connect}" -X POST "$FRONTEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"test${TIMESTAMP}\",\"email\":\"test${TIMESTAMP}@test.com\",\"password\":\"test123\",\"grade_level\":3}" 2>/dev/null)
PROXY_REGISTER_CODE=$(echo "$PROXY_REGISTER_RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
PROXY_REGISTER_TIME=$(echo "$PROXY_REGISTER_RESPONSE" | grep -o "TIME_TOTAL:[0-9.]*" | cut -d: -f2)
PROXY_REGISTER_CONNECT=$(echo "$PROXY_REGISTER_RESPONSE" | grep -o "TIME_CONNECT:[0-9.]*" | cut -d: -f2)
PROXY_REGISTER_BODY=$(echo "$PROXY_REGISTER_RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//' | sed 's/TIME_TOTAL:[0-9.]*$//' | sed 's/TIME_CONNECT:[0-9.]*$//')

echo "   Response time: ${PROXY_REGISTER_TIME}s (connect: ${PROXY_REGISTER_CONNECT}s)"
if [ "$PROXY_REGISTER_CODE" = "200" ] || [ "$PROXY_REGISTER_CODE" = "201" ]; then
    echo "   ✅ Proxy registration: HTTP $PROXY_REGISTER_CODE"
elif [ "$PROXY_REGISTER_CODE" = "502" ]; then
    echo "   ❌ Proxy registration: HTTP $PROXY_REGISTER_CODE (Bad Gateway)"
    echo "   This means nginx can't reach the backend"
    echo "   Possible causes:"
    echo "     - BACKEND_URL not substituted in nginx config"
    echo "     - Backend URL is incorrect"
    echo "     - Network connectivity issue"
    echo "   Response body: $(echo "$PROXY_REGISTER_BODY" | head -2 | tr '\n' ' ')"
elif [ "$PROXY_REGISTER_CODE" = "504" ]; then
    echo "   ❌ Proxy registration: HTTP $PROXY_REGISTER_CODE (Gateway Timeout)"
    echo "   This means nginx timed out waiting for backend"
    echo "   Time taken: ${PROXY_REGISTER_TIME}s"
    echo "   Backend might be slow (OpenAI calls?)"
else
    echo "   ❌ Proxy registration: HTTP $PROXY_REGISTER_CODE"
    echo "   Response: $(echo "$PROXY_REGISTER_BODY" | head -3 | tr '\n' ' ')"
fi

echo ""
echo "   Comparison:"
echo "   - Health check (GET /): Works (static file, no proxy)"
echo "   - API test (GET /api/profile): HTTP $API_TEST_CODE"
echo "   - Registration (POST /api/register): HTTP $PROXY_REGISTER_CODE"
if [ "$FRONTEND_HEALTH" = "200" ] && [ "$PROXY_REGISTER_CODE" = "502" ]; then
    echo "   ⚠️  ISSUE: Static files work but API proxy fails"
    echo "   This confirms nginx is running but proxy_pass is misconfigured"
fi

echo ""

# Check nginx logs
echo "4. Checking frontend (nginx) logs for errors..."
echo ""
echo "   Recent nginx errors (last 20):"
gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1 | grep -E "(error|ERROR|502|504|proxy|upstream|connect|failed)" | tail -20 || echo "   No relevant errors found"

echo ""
echo "   Startup logs (template processing):"
gcloud run services logs read lunareading-frontend --region $REGION --limit 200 2>&1 | grep -E "(Processing|BACKEND_URL|template|Nginx config|✅|ERROR)" | tail -10 || echo "   No startup logs found"

echo ""
echo "   Recent access logs (last 10 requests):"
gcloud run services logs read lunareading-frontend --region $REGION --limit 30 2>&1 | grep -E "(GET|POST)" | tail -10 || echo "   No access logs found"

echo ""

# Check backend logs
echo "5. Checking backend logs (recent requests)..."
echo ""
gcloud run services logs read lunareading-backend --region $REGION --limit 30 2>&1 | grep -E "(POST|GET|/api)" | tail -10 || echo "   No recent API requests found"

echo ""

# Test with verbose curl to see what's happening
echo "6. Testing proxy with verbose output..."
echo ""
echo "   Testing: POST $FRONTEND_URL/api/register"
echo "   (This will show detailed request/response)"
echo ""

VERBOSE_OUTPUT=$(curl -v -X POST "$FRONTEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}' \
  2>&1)

echo "   Request details:"
echo "$VERBOSE_OUTPUT" | grep -E "(> POST|> Host|> Content-Type|> Content-Length)" | head -5

echo ""
echo "   Response details:"
echo "$VERBOSE_OUTPUT" | grep -E "(< HTTP|< Server|< Content-Type)" | head -5

echo ""
echo "   Error details (if any):"
echo "$VERBOSE_OUTPUT" | grep -E "(502|504|upstream|connect|failed|error)" | head -5 || echo "   No specific error messages found"

echo ""
echo "7. Analyzing the difference..."
echo ""
if [ "$FRONTEND_HEALTH" = "200" ] && [ "$PROXY_REGISTER_CODE" = "502" ]; then
    echo "   ✅ Health check (GET /) works - nginx is serving static files"
    echo "   ❌ API proxy (POST /api/register) fails - nginx can't proxy to backend"
    echo ""
    echo "   This indicates:"
    echo "   1. Nginx is running correctly"
    echo "   2. Static file serving works"
    echo "   3. Proxy configuration is the problem"
    echo ""
    echo "   Most likely causes:"
    echo "   - BACKEND_URL not substituted in nginx config (check startup logs)"
    echo "   - proxy_pass directive is incorrect"
    echo "   - Backend URL format issue"
    echo ""
    echo "   Check startup logs for:"
    echo "   - 'Processing nginx template with BACKEND_URL=...'"
    echo "   - '✅ BACKEND_URL substituted successfully'"
    echo "   - 'proxy_pass: proxy_pass https://...'"
elif [ "$FRONTEND_HEALTH" = "200" ] && [ "$API_TEST_CODE" = "502" ]; then
    echo "   ✅ Health check works"
    echo "   ❌ API proxy fails for both GET and POST"
    echo "   This confirms the /api location block is misconfigured"
elif [ "$FRONTEND_HEALTH" != "200" ]; then
    echo "   ❌ Even health check fails - nginx might not be running"
    echo "   Check container startup logs"
fi

echo ""
echo ""
echo "📝 Summary and Recommendations:"
echo ""

if [ "$FRONTEND_HEALTH" = "200" ] && [ "$PROXY_REGISTER_CODE" = "502" ]; then
    echo "🔍 DIAGNOSIS: Health check works but API proxy fails"
    echo ""
    echo "This means:"
    echo "  ✅ Nginx is running"
    echo "  ✅ Static file serving works (GET /)"
    echo "  ❌ Proxy configuration is broken (POST /api/register)"
    echo ""
    echo "Root cause: Nginx can't proxy to backend"
    echo ""
    if [ -z "$BACKEND_FROM_ENV" ]; then
        echo "1. ❌ BACKEND_URL is NOT set in environment variables"
        echo "   Fix: ./fix_backend_url.sh $REGION"
        echo ""
        echo "2. After fixing, check startup logs:"
        echo "   ./check_startup_logs.sh $REGION"
        echo "   Should see: '✅ BACKEND_URL substituted successfully'"
    elif [ "$BACKEND_FROM_ENV" != "$BACKEND_URL" ]; then
        echo "1. ⚠️  BACKEND_URL is set but incorrect"
        echo "   Current: $BACKEND_FROM_ENV"
        echo "   Should be: $BACKEND_URL"
        echo "   Fix: ./fix_backend_url.sh $REGION"
    else
        echo "1. ✅ BACKEND_URL is set correctly: $BACKEND_FROM_ENV"
        echo "   But proxy still fails - check:"
        echo "   - Startup logs: ./check_startup_logs.sh $REGION"
        echo "   - Verify template was processed: Should see '✅ BACKEND_URL substituted'"
        echo "   - Check nginx error logs: ./check_nginx_errors.sh $REGION"
        echo ""
        echo "   If template wasn't processed, rebuild:"
        echo "   ./fix_backend_url.sh $REGION"
    fi
elif [ "$PROXY_REGISTER_CODE" = "504" ]; then
    echo "🔍 DIAGNOSIS: Gateway Timeout"
    echo ""
    echo "Nginx is proxying but backend is too slow"
    echo "Fix: ./fix_504_timeout.sh $REGION"
elif [ "$PROXY_REGISTER_CODE" = "200" ] || [ "$PROXY_REGISTER_CODE" = "201" ]; then
    echo "✅ Frontend proxy is working!"
    echo ""
    echo "If it still doesn't work in the browser:"
    echo "1. Check browser console (F12) for JavaScript errors"
    echo "2. Check Network tab to see actual request URL"
    echo "3. Verify frontend code uses relative URLs (/api/...)"
else
    echo "❌ Frontend proxy is NOT working correctly"
    echo ""
    echo "Next steps:"
    echo "1. Check startup logs: ./check_startup_logs.sh $REGION"
    echo "2. Check nginx errors: ./check_nginx_errors.sh $REGION"
    echo "3. Fix BACKEND_URL: ./fix_backend_url.sh $REGION"
fi

echo ""
echo "🔧 Quick Fix Command:"
echo "   ./fix_backend_url.sh $REGION"

