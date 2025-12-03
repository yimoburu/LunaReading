#!/bin/bash
# Check frontend logs to see why container isn't starting

REGION=${1:-"us-central1"}

echo "🔍 Checking Frontend Logs"
echo "========================"
echo ""

echo "Recent logs (last 100 lines):"
echo ""
gcloud run services logs read lunareading-frontend --region $REGION --limit 100 2>&1 | tail -50

echo ""
echo ""
echo "Looking for errors..."
gcloud run services logs read lunareading-frontend --region $REGION --limit 200 2>&1 | grep -iE "(error|fail|exit|nginx|script|BACKEND_URL)" | tail -20

