#!/bin/bash
# Test if the startup script is actually running by checking for its output

REGION=${1:-"us-central1"}

echo "🔍 Testing Startup Script Execution"
echo "===================================="
echo ""

echo "Looking for startup script output in logs..."
echo ""

LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 500 2>&1)

echo "1. Looking for '=== Processing Nginx Template ==='..."
TEMPLATE_START=$(echo "$LOGS" | grep -E "=== Processing Nginx Template ===" | tail -5)
if [ -n "$TEMPLATE_START" ]; then
    echo "   ✅ Found template processing start"
    echo "$TEMPLATE_START"
else
    echo "   ❌ Startup script is NOT running!"
    echo "   The script should output: '=== Processing Nginx Template ==='"
fi

echo ""
echo "2. Looking for 'BACKEND_URL='..."
BACKEND_LOGS=$(echo "$LOGS" | grep -E "BACKEND_URL=" | tail -5)
if [ -n "$BACKEND_LOGS" ]; then
    echo "   ✅ Found BACKEND_URL logs"
    echo "$BACKEND_LOGS"
else
    echo "   ❌ No BACKEND_URL logs found"
fi

echo ""
echo "3. Looking for '✅ BACKEND_URL substituted successfully'..."
SUCCESS_LOGS=$(echo "$LOGS" | grep -E "✅.*substituted|substituted successfully" | tail -5)
if [ -n "$SUCCESS_LOGS" ]; then
    echo "   ✅ Template substitution succeeded!"
    echo "$SUCCESS_LOGS"
else
    echo "   ❌ Template substitution did NOT succeed (or script didn't run)"
fi

echo ""
echo "4. Looking for 'Generated proxy_pass'..."
PROXY_LOGS=$(echo "$LOGS" | grep -E "Generated proxy_pass|proxy_pass:" | tail -5)
if [ -n "$PROXY_LOGS" ]; then
    echo "   ✅ Found proxy_pass configuration"
    echo "$PROXY_LOGS"
else
    echo "   ❌ No proxy_pass logs found"
fi

echo ""
echo "5. Looking for errors..."
ERROR_LOGS=$(echo "$LOGS" | grep -E "❌.*ERROR|ERROR.*BACKEND_URL" | tail -5)
if [ -n "$ERROR_LOGS" ]; then
    echo "   ❌ Found errors in template processing!"
    echo "$ERROR_LOGS"
else
    echo "   No errors found"
fi

echo ""
echo "6. Full startup sequence (looking for entrypoint script execution)..."
echo ""
# Get logs that might show script execution
SCRIPT_LOGS=$(echo "$LOGS" | grep -E "(docker-entrypoint|entrypoint|Processing|template|BACKEND_URL)" | head -30)
if [ -n "$SCRIPT_LOGS" ]; then
    echo "$SCRIPT_LOGS"
else
    echo "   ⚠️  No entrypoint script logs found"
    echo "   This suggests the script isn't running"
fi

echo ""
echo "📝 Summary:"
if [ -z "$TEMPLATE_START" ]; then
    echo "   ❌ PROBLEM: Startup script is NOT running"
    echo ""
    echo "   Possible causes:"
    echo "   1. Script file doesn't exist in container"
    echo "   2. Script doesn't have execute permissions"
    echo "   3. nginx:alpine entrypoint isn't running scripts in /docker-entrypoint.d/"
    echo "   4. Container is crashing before script runs"
    echo ""
    echo "   Solution: Check Dockerfile.frontend to ensure script is created correctly"
elif [ -z "$SUCCESS_LOGS" ]; then
    echo "   ⚠️  Startup script is running, but template substitution failed"
    echo "   Check the error logs above"
else
    echo "   ✅ Startup script is running and template was processed"
fi

