#!/bin/bash
# Verify nginx proxy configuration is correct

REGION=${1:-"us-central1"}

echo "🔍 Verifying Nginx Proxy Configuration"
echo "======================================="
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found!"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

# Check if BACKEND_URL is set
echo "1. Checking BACKEND_URL environment variable..."
ENV_VARS=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)

# Parse JSON-like format: {'name': 'BACKEND_URL', 'value': 'https://...'}
# Extract the value after 'value': ' (handle different spacing)
BACKEND_FROM_ENV=$(echo "$ENV_VARS" | sed -n "s/.*'name'[[:space:]]*:[[:space:]]*'BACKEND_URL'.*'value'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" || echo "")

if [ -n "$BACKEND_FROM_ENV" ]; then
    echo "   ✅ BACKEND_URL is set: $BACKEND_FROM_ENV"
    if [ "$BACKEND_FROM_ENV" != "$BACKEND_URL" ]; then
        echo "   ⚠️  WARNING: Doesn't match actual backend URL!"
    fi
else
    echo "   ❌ BACKEND_URL is NOT set"
    echo "   This is the problem!"
fi

echo ""
echo "2. Checking startup logs for template processing..."
echo ""
STARTUP_LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 200 2>&1 | grep -E "(Processing|BACKEND_URL|template|Nginx config|✅|ERROR|proxy_pass)" | tail -15)

if echo "$STARTUP_LOGS" | grep -q "Processing nginx template"; then
    echo "   ✅ Template processing script ran"
    BACKEND_IN_LOG=$(echo "$STARTUP_LOGS" | grep "BACKEND_URL=" | tail -1)
    if [ -n "$BACKEND_IN_LOG" ]; then
        echo "   $BACKEND_IN_LOG"
    fi
else
    echo "   ⚠️  No template processing logs found"
    echo "   The startup script might not be running"
fi

if echo "$STARTUP_LOGS" | grep -q "✅"; then
    echo "   ✅ Template was processed successfully"
    PROXY_PASS_LINE=$(echo "$STARTUP_LOGS" | grep "proxy_pass" | tail -1)
    if [ -n "$PROXY_PASS_LINE" ]; then
        echo "   $PROXY_PASS_LINE"
    fi
elif echo "$STARTUP_LOGS" | grep -q "ERROR"; then
    echo "   ❌ Template processing failed!"
    echo "$STARTUP_LOGS" | grep "ERROR" | tail -3
else
    echo "   ⚠️  Could not verify template processing"
fi

echo ""
echo "3. Testing different API endpoints through proxy..."
echo ""

# Test GET /api/profile (should return 401, but means proxy works)
echo "   GET /api/profile (should return 401 if proxy works):"
PROFILE_TEST=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/api/profile" 2>/dev/null || echo "000")
if [ "$PROFILE_TEST" = "401" ] || [ "$PROFILE_TEST" = "403" ]; then
    echo "   ✅ Proxy works! HTTP $PROFILE_TEST (auth failed, but proxy succeeded)"
elif [ "$PROFILE_TEST" = "502" ]; then
    echo "   ❌ Proxy failed: HTTP $PROFILE_TEST (nginx can't reach backend)"
else
    echo "   ⚠️  HTTP $PROFILE_TEST"
fi

# Test POST /api/register
echo ""
echo "   POST /api/register:"
REGISTER_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FRONTEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"test'$(date +%s)'","email":"test'$(date +%s)'@test.com","password":"test123","grade_level":3}' 2>/dev/null || echo "000")
if [ "$REGISTER_TEST" = "200" ] || [ "$REGISTER_TEST" = "201" ]; then
    echo "   ✅ Proxy works! HTTP $REGISTER_TEST"
elif [ "$REGISTER_TEST" = "502" ]; then
    echo "   ❌ Proxy failed: HTTP $REGISTER_TEST (nginx can't reach backend)"
else
    echo "   ⚠️  HTTP $REGISTER_TEST"
fi

echo ""
echo "4. The issue:"
if [ "$PROFILE_TEST" = "502" ] && [ "$REGISTER_TEST" = "502" ]; then
    echo "   ❌ All API requests return 502"
    echo "   This means nginx proxy_pass is not configured correctly"
    echo ""
    echo "   Most likely causes:"
    echo "   1. BACKEND_URL not substituted in nginx config"
    echo "   2. proxy_pass syntax is incorrect"
    echo "   3. Backend URL format issue"
    echo ""
    echo "   Fix: ./fix_backend_url.sh $REGION"
    echo "   Then check logs: ./check_startup_logs.sh $REGION"
elif [ "$PROFILE_TEST" = "401" ] && [ "$REGISTER_TEST" = "502" ]; then
    echo "   ⚠️  GET works but POST fails"
    echo "   This might be a timeout issue or backend processing issue"
elif [ "$PROFILE_TEST" != "502" ] && [ "$REGISTER_TEST" != "502" ]; then
    echo "   ✅ Proxy is working!"
fi

