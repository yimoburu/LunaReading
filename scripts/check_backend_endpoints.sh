#!/bin/bash
# Check if backend endpoints are available
# Helps diagnose 404 errors

set -e

REGION=${1:-"us-central1"}
SERVICE_NAME="lunareading-backend"

echo "🔍 Checking Backend Endpoints"
echo "=============================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Could not get backend URL"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

# Test endpoints
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo "Testing: $description"
    echo "  URL: ${BACKEND_URL}${endpoint}"
    
    HTTP_CODE=$(curl -s -o /tmp/response_body.txt -w "%{http_code}" "${BACKEND_URL}${endpoint}" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  ✅ Status: 200 OK"
        RESPONSE_BODY=$(cat /tmp/response_body.txt | head -c 200)
        echo "  Response: ${RESPONSE_BODY}..."
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "  ❌ Status: 404 Not Found"
        echo "  ⚠️  This endpoint is not available in the deployed backend"
        echo "  The code may have this endpoint, but it's not in the deployed version"
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "  ❌ Status: Connection Failed"
        echo "  Cannot connect to backend"
    else
        echo "  ⚠️  Status: $HTTP_CODE"
        RESPONSE_BODY=$(cat /tmp/response_body.txt | head -c 200)
        echo "  Response: ${RESPONSE_BODY}..."
    fi
    echo ""
}

# Test root endpoint
test_endpoint "/" "Root endpoint (health check)"

# Test database status endpoint
test_endpoint "/api/db-status" "Database status endpoint"

# Test register endpoint (should exist)
test_endpoint "/api/register" "Register endpoint (POST required, but checking if route exists)"

# Test login endpoint
test_endpoint "/api/login" "Login endpoint (POST required, but checking if route exists)"

echo "=========================================="
echo "📋 Summary"
echo "=========================================="
echo ""
echo "If /api/db-status returns 404:"
echo "  1. The endpoint exists in code but may not be deployed"
echo "  2. Redeploy the backend:"
echo "     ./deploy-no-docker.sh"
echo "     OR"
echo "     gcloud run deploy $SERVICE_NAME --source . --region $REGION"
echo ""
echo "If root endpoint (/) works but /api/db-status doesn't:"
echo "  - The backend is running but missing the /api/db-status route"
echo "  - This suggests the deployed code is older than the current code"
echo ""
echo "To check what's deployed:"
echo "  gcloud run services logs read $SERVICE_NAME --region $REGION --limit 20"
echo ""

