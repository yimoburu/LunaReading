#!/bin/bash
# Check if nginx template was correctly substituted

REGION=${1:-"us-central1"}

echo "🔍 Checking Nginx Template Substitution"
echo "========================================"
echo ""

echo "1. Checking if custom entrypoint ran..."
LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 200 2>&1)

ENTRYPOINT_LOGS=$(echo "$LOGS" | grep -E "(Nginx Entrypoint|BACKEND_URL=|===)" | tail -10)
if [ -n "$ENTRYPOINT_LOGS" ]; then
    echo "   ✅ Found custom entrypoint logs:"
    echo "$ENTRYPOINT_LOGS"
else
    echo "   ❌ Custom entrypoint did NOT run!"
    echo "   This means docker-entrypoint.sh is not being used"
    echo "   Check if the image was rebuilt with the new Dockerfile"
fi

echo ""
echo "2. Checking if BACKEND_URL was substituted..."
VERIFY_LOGS=$(echo "$LOGS" | grep -E "(Verifying|substituted|proxy_pass)" | tail -10)
if [ -n "$VERIFY_LOGS" ]; then
    echo "   ✅ Found verification logs:"
    echo "$VERIFY_LOGS"
    
    # Check if substitution succeeded
    if echo "$VERIFY_LOGS" | grep -q "✅.*substituted"; then
        echo "   ✅ Template substitution SUCCEEDED"
        PROXY_PASS=$(echo "$VERIFY_LOGS" | grep "proxy_pass:" | tail -1)
        if [ -n "$PROXY_PASS" ]; then
            echo "   $PROXY_PASS"
        fi
    elif echo "$VERIFY_LOGS" | grep -q "❌.*ERROR"; then
        echo "   ❌ Template substitution FAILED!"
        echo "   Check the error above"
    fi
else
    echo "   ⚠️  No verification logs found"
    echo "   The verification script might not be running"
fi

echo ""
echo "3. Checking nginx error logs for proxy issues..."
ERROR_LOGS=$(echo "$LOGS" | grep -E "(502|upstream|connect|failed|error)" | tail -15)
if [ -n "$ERROR_LOGS" ]; then
    echo "   Found error logs:"
    echo "$ERROR_LOGS"
    
    # Check for specific errors
    if echo "$ERROR_LOGS" | grep -q "upstream"; then
        echo ""
        echo "   ⚠️  Upstream error detected - nginx can't reach backend"
    fi
    if echo "$ERROR_LOGS" | grep -q "connect"; then
        echo ""
        echo "   ⚠️  Connection error - check if backend URL is correct"
    fi
else
    echo "   No specific error messages found"
fi

echo ""
echo "4. Checking BACKEND_URL environment variable..."
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
ENV_VARS=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)
BACKEND_FROM_ENV=$(echo "$ENV_VARS" | sed -n "s/.*'name'[[:space:]]*:[[:space:]]*'BACKEND_URL'.*'value'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" || echo "")

if [ -n "$BACKEND_FROM_ENV" ]; then
    echo "   ✅ BACKEND_URL is set: $BACKEND_FROM_ENV"
    if [ "$BACKEND_FROM_ENV" = "$BACKEND_URL" ]; then
        echo "   ✅ Matches actual backend URL"
    else
        echo "   ⚠️  Doesn't match actual backend URL ($BACKEND_URL)"
    fi
else
    echo "   ❌ BACKEND_URL is NOT set in environment!"
fi

echo ""
echo "5. Recent startup sequence (last 40 lines)..."
echo "$LOGS" | tail -40

echo ""
echo "📝 Diagnosis:"
if [ -z "$ENTRYPOINT_LOGS" ]; then
    echo "   ❌ PROBLEM: Custom entrypoint is not running"
    echo "   Solution: Rebuild frontend with: ./comprehensive_fix_502.sh $REGION"
elif echo "$VERIFY_LOGS" | grep -q "❌.*ERROR"; then
    echo "   ❌ PROBLEM: Template substitution failed"
    echo "   Check the error message above"
elif [ -z "$BACKEND_FROM_ENV" ]; then
    echo "   ❌ PROBLEM: BACKEND_URL not set in environment"
    echo "   Solution: gcloud run services update lunareading-frontend --region $REGION --set-env-vars \"BACKEND_URL=$BACKEND_URL\""
else
    echo "   ⚠️  BACKEND_URL is set and entrypoint ran, but proxy still fails"
    echo "   Possible causes:"
    echo "   1. Template substitution happened but URL is wrong"
    echo "   2. Network connectivity issue"
    echo "   3. Backend is not accessible from frontend container"
    echo ""
    echo "   Check the proxy_pass value in verification logs above"
fi

