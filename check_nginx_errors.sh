#!/bin/bash
# Check nginx error logs for proxy issues

REGION=${1:-"us-central1"}

echo "🔍 Checking Nginx Error Logs"
echo "=============================="
echo ""

echo "Recent nginx errors (last 50 lines):"
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1 | grep -E "(error|ERROR|502|upstream|proxy|connect|failed|BACKEND_URL)" | tail -30

echo ""
echo ""
echo "All recent logs (last 30 lines):"
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 30 2>&1 | tail -30

