#!/bin/bash
# Debug Cloud Run container startup issues

REGION=${1:-"us-central1"}

echo "🔍 Debugging Cloud Run Container Startup"
echo "========================================"
echo ""

echo "1. Checking recent logs..."
echo ""
gcloud run services logs read lunareading-backend --region $REGION --limit 100 2>&1 | grep -E "(ERROR|error|failed|Exception|Traceback|Database|SQL)" | tail -20

echo ""
echo "2. Checking service configuration..."
echo ""
gcloud run services describe lunareading-backend --region $REGION --format="yaml(spec.template.spec.containers[0].env)" 2>&1 | head -30

echo ""
echo "3. Checking Cloud SQL connection..."
echo ""
gcloud run services describe lunareading-backend --region $REGION --format="yaml(spec.template.spec.containers[0].cloudSqlInstances)" 2>&1

echo ""
echo "4. Common issues to check:"
echo "   - Database connection string format"
echo "   - Cloud SQL instance permissions"
echo "   - Missing MySQL dependencies (pymysql)"
echo "   - Database tables not created"
echo ""
echo "5. To view full logs:"
echo "   gcloud run services logs read lunareading-backend --region $REGION --limit 200"

