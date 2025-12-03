#!/bin/bash
# Check what nginx configuration is actually being used

REGION=${1:-"us-central1"}

echo "🔍 Checking Nginx Configuration"
echo "==============================="
echo ""

echo "1. Checking startup logs for template processing..."
echo ""
LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 500 2>&1)

echo "   Looking for template processing messages..."
TEMPLATE_LOGS=$(echo "$LOGS" | grep -E "(Processing|BACKEND_URL|template|envsubst|✅|❌|ERROR)" | tail -20)
if [ -n "$TEMPLATE_LOGS" ]; then
    echo "$TEMPLATE_LOGS"
else
    echo "   ⚠️  No template processing logs found!"
    echo "   This means the startup script might not be running"
fi

echo ""
echo "2. Checking for BACKEND_URL in environment..."
ENV_LOGS=$(echo "$LOGS" | grep -E "BACKEND_URL" | tail -10)
if [ -n "$ENV_LOGS" ]; then
    echo "$ENV_LOGS"
else
    echo "   ⚠️  No BACKEND_URL logs found"
fi

echo ""
echo "3. Checking nginx startup..."
NGINX_START=$(echo "$LOGS" | grep -E "(nginx|started|ready|daemon)" | tail -10)
if [ -n "$NGINX_START" ]; then
    echo "$NGINX_START"
else
    echo "   ⚠️  No nginx startup logs found"
fi

echo ""
echo "4. Recent container startup (first 50 lines of most recent startup)..."
echo ""
# Get the most recent container startup by looking for the first log entry after a gap
echo "$LOGS" | head -50

echo ""
echo "5. Checking if BACKEND_URL is set in Cloud Run service..."
ENV_VARS=$(gcloud run services describe lunareading-frontend --region $REGION --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)

# Parse JSON-like format: {'name': 'BACKEND_URL', 'value': 'https://...'}
# Extract the value after 'value': ' (handle different spacing)
BACKEND_FROM_ENV=$(echo "$ENV_VARS" | sed -n "s/.*'name'[[:space:]]*:[[:space:]]*'BACKEND_URL'.*'value'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" || echo "")

if [ -n "$BACKEND_FROM_ENV" ]; then
    echo "   ✅ BACKEND_URL is set in service: $BACKEND_FROM_ENV"
else
    echo "   ❌ BACKEND_URL is NOT set in Cloud Run service!"
    echo "   This is the problem - the environment variable isn't available to the container"
fi

echo ""
echo "6. Testing if we can see the actual nginx config..."
echo "   (This would require exec into container, which Cloud Run doesn't support)"
echo "   Instead, checking error logs for proxy issues..."

ERROR_LOGS=$(echo "$LOGS" | grep -E "(error|ERROR|upstream|connect|failed)" | tail -10)
if [ -n "$ERROR_LOGS" ]; then
    echo "$ERROR_LOGS"
else
    echo "   No specific error messages found"
fi

echo ""
echo "📝 Diagnosis:"
if [ -z "$BACKEND_FROM_ENV" ]; then
    echo "   ❌ BACKEND_URL is not set in Cloud Run service"
    echo "   Fix: gcloud run services update lunareading-frontend --region $REGION --set-env-vars \"BACKEND_URL=<backend-url>\""
elif [ -z "$TEMPLATE_LOGS" ]; then
    echo "   ⚠️  Template processing logs not found"
    echo "   Possible causes:"
    echo "   1. Startup script isn't running"
    echo "   2. Logs are being filtered out"
    echo "   3. Container is crashing before script runs"
    echo ""
    echo "   Check full logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 200"
else
    echo "   ✅ Found template processing logs"
    echo "   Check the logs above to see if substitution succeeded"
fi

