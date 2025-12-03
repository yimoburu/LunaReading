#!/bin/bash
# Check startup logs to see if template processing worked

REGION=${1:-"us-central1"}

echo "🔍 Checking Startup Logs"
echo "======================="
echo ""

echo "Looking for template processing messages..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 200 2>&1 | grep -E "(Processing|BACKEND_URL|Nginx config|template|envsubst|ERROR|✅)" | tail -20

echo ""
echo ""
echo "Recent startup logs (last 50 lines)..."
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 50 2>&1 | tail -30

