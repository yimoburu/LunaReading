#!/bin/bash
# Rebuild both backend and frontend services

REGION=${1:-"us-central1"}

echo "🔧 Rebuilding Backend and Frontend"
echo "==================================="
echo ""

# Get backend URL (will be set after backend is deployed)
BACKEND_URL=""

echo "Step 1: Rebuilding Backend..."
echo ""

cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '-t'
    - 'gcr.io/lunareading-app/lunareading-backend:latest'
    - '-f'
    - 'Dockerfile.backend'
    - '.'
images:
- 'gcr.io/lunareading-app/lunareading-backend:latest'
EOF

echo "   Building backend image..."
gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=$REGION
rm /tmp/cloudbuild-backend.yaml

echo ""
echo "✅ Backend image rebuilt"
echo ""

echo "Step 2: Redeploying Backend..."
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --timeout 300 \
  --set-env-vars "OPENAI_API_KEY=$(gcloud run services describe lunareading-backend --region $REGION --format='value(spec.template.spec.containers[0].env[?name==`OPENAI_API_KEY`].value)' 2>/dev/null || echo '')" \
  --quiet

echo "✅ Backend redeployed"
echo ""

echo "Step 3: Getting Backend URL..."
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Failed to get backend URL!"
    exit 1
fi

echo "   Backend URL: $BACKEND_URL"
echo ""

echo "Step 4: Setting BACKEND_URL for frontend..."
gcloud run services update lunareading-frontend \
  --region $REGION \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo "✅ BACKEND_URL set"
echo ""

echo "Step 5: Rebuilding Frontend..."
echo ""

cat > /tmp/cloudbuild-frontend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '--build-arg'
    - 'REACT_APP_API_URL='
    - '-t'
    - 'gcr.io/lunareading-app/lunareading-frontend:latest'
    - '-f'
    - 'Dockerfile.frontend'
    - '.'
images:
- 'gcr.io/lunareading-app/lunareading-frontend:latest'
EOF

echo "   Building frontend image..."
gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION
rm /tmp/cloudbuild-frontend.yaml

echo ""
echo "✅ Frontend image rebuilt"
echo ""

echo "Step 6: Redeploying Frontend..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --timeout 300 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet

echo ""
echo "✅ Frontend redeployed"
echo ""

echo "Step 7: Waiting for services to stabilize..."
sleep 15

echo ""
echo "Step 8: Getting service URLs..."
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

echo ""
echo "📝 Summary:"
echo "  Backend URL: $BACKEND_URL"
echo "  Frontend URL: $FRONTEND_URL"
echo ""

echo "Step 9: Testing services..."
echo ""

# Test backend
echo "   Testing backend health..."
BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")
if [ "$BACKEND_HEALTH" = "200" ]; then
    echo "   ✅ Backend health: HTTP $BACKEND_HEALTH"
else
    echo "   ⚠️  Backend health: HTTP $BACKEND_HEALTH"
fi

# Test frontend
echo "   Testing frontend health..."
FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/" 2>/dev/null || echo "000")
if [ "$FRONTEND_HEALTH" = "200" ]; then
    echo "   ✅ Frontend health: HTTP $FRONTEND_HEALTH"
else
    echo "   ⚠️  Frontend health: HTTP $FRONTEND_HEALTH"
fi

# Test proxy
echo "   Testing frontend proxy..."
TIMESTAMP=$(date +%s)
PROXY_TEST=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FRONTEND_URL/api/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"test${TIMESTAMP}\",\"email\":\"test${TIMESTAMP}@test.com\",\"password\":\"test123\",\"grade_level\":3}" \
  --max-time 30 2>/dev/null || echo "000")

if [ "$PROXY_TEST" = "200" ] || [ "$PROXY_TEST" = "201" ]; then
    echo "   ✅ Frontend proxy: HTTP $PROXY_TEST - SUCCESS!"
    echo ""
    echo "🎉 All services rebuilt and working!"
elif [ "$PROXY_TEST" = "502" ]; then
    echo "   ❌ Frontend proxy: HTTP $PROXY_TEST - Still failing"
    echo "   Check logs: gcloud run services logs read lunareading-frontend --region $REGION --limit 50"
else
    echo "   ⚠️  Frontend proxy: HTTP $PROXY_TEST"
fi

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "Access your application at: $FRONTEND_URL"

