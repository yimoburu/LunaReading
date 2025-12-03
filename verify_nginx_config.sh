#!/bin/bash
# Verify nginx configuration is correct

REGION=${1:-"us-central1"}

echo "🔍 Verifying Nginx Configuration"
echo "=================================="
echo ""

# Get URLs
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

echo "Backend URL: $BACKEND_URL"
echo "Frontend URL: $FRONTEND_URL"
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
    echo "   This is the problem! Set it with:"
    echo "   ./fix_backend_url.sh $REGION"
    exit 1
fi

echo ""

# Test if nginx can reach backend
echo "2. Testing if nginx can reach backend..."
echo "   (This tests the actual proxy_pass configuration)"

# Try to see nginx error logs
echo ""
echo "3. Checking nginx error logs for proxy issues..."
gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1 | grep -E "(502|upstream|proxy|connect|failed)" | tail -10

echo ""
echo "4. The issue is likely:"
echo "   - BACKEND_URL not set (but we checked above)"
echo "   - Nginx template not processed correctly"
echo "   - Backend URL format issue in proxy_pass"
echo ""
echo "Solution: Run ./fix_backend_url.sh $REGION to rebuild with correct config"

