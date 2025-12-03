#!/bin/bash
# Verify that nginx template was processed correctly

REGION=${1:-"us-central1"}

echo "🔍 Verifying Nginx Template Processing"
echo "======================================"
echo ""

echo "Checking startup logs for template processing..."
echo ""

# Get recent logs
LOGS=$(gcloud run services logs read lunareading-frontend --region $REGION --limit 200 2>&1)

echo "1. BACKEND_URL setting:"
echo "$LOGS" | grep -E "(BACKEND_URL=|Setting BACKEND_URL)" | tail -5

echo ""
echo "2. Template processing (nginx:alpine automatic):"
echo "$LOGS" | grep -E "(template|envsubst|Processing|nginx)" | tail -5

echo ""
echo "3. Nginx startup:"
echo "$LOGS" | grep -E "(nginx|started|ready)" | tail -5

echo ""
echo "4. Errors (if any):"
ERRORS=$(echo "$LOGS" | grep -E "(ERROR|error|failed|502|504)" | tail -10)
if [ -n "$ERRORS" ]; then
    echo "$ERRORS"
else
    echo "   No errors found"
fi

echo ""
echo "5. Full startup sequence (last 30 lines):"
echo "$LOGS" | tail -30

echo ""
echo "📝 What to look for:"
echo "   ✅ 'BACKEND_URL=https://...' - URL is set"
echo "   ✅ 'nginx' or 'started' - nginx started successfully"
echo "   ❌ 'ERROR' or 'failed' - something went wrong"
echo "   ❌ '${BACKEND_URL}' in logs - substitution failed"

