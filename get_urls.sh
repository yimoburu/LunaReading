#!/bin/bash
# Get Cloud Run service URLs

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🔗 Cloud Run Service URLs"
echo "========================="
echo ""

# Get backend URL
echo "Backend:"
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)
if [ -n "$BACKEND_URL" ]; then
    echo "  $BACKEND_URL"
    echo ""
    echo "  Test endpoints:"
    echo "  - Health check: $BACKEND_URL/"
    echo "  - API info: $BACKEND_URL/api/profile (requires auth)"
else
    echo "  ❌ Backend not deployed yet"
    echo "  Deploy with: ./deploy-no-docker.sh $PROJECT_ID $REGION"
fi

echo ""

# Get frontend URL
echo "Frontend:"
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)
if [ -n "$FRONTEND_URL" ]; then
    echo "  $FRONTEND_URL"
    echo ""
    echo "  Open in browser: $FRONTEND_URL"
else
    echo "  ❌ Frontend not deployed yet"
    echo "  Deploy with: ./deploy-no-docker.sh $PROJECT_ID $REGION"
fi

echo ""
echo "📝 Quick Commands:"
echo "  Get backend URL:  gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)'"
echo "  Get frontend URL: gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)'"
echo "  List all services: gcloud run services list --region $REGION"

