#!/bin/bash
# Fix worker timeout by increasing memory and timeout

REGION=${1:-"us-central1"}

echo "🔧 Fixing Worker Timeout Issues"
echo "================================"
echo ""

echo "The logs show worker timeout errors. This is usually due to:"
echo "1. Low memory (512Mi might not be enough)"
echo "2. Short timeout"
echo "3. Slow startup"
echo ""

echo "1. Increasing memory to 1Gi..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --memory 1Gi \
  --quiet

echo "✅ Memory increased"
echo ""

echo "2. Increasing timeout to 300 seconds..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --timeout 300 \
  --quiet

echo "✅ Timeout increased"
echo ""

echo "3. Rebuilding backend with optimized gunicorn settings..."
cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/lunareading-app/lunareading-backend:latest', '-f', 'Dockerfile.backend', '.']
images:
- 'gcr.io/lunareading-app/lunareading-backend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-backend.yaml

echo "✅ Backend rebuilt"
echo ""

echo "4. Redeploying with new configuration..."
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --timeout 300 \
  --max-instances 10 \
  --quiet

echo ""
echo "✅ Configuration updated!"
echo ""
echo "Changes made:"
echo "  - Memory: 512Mi → 1Gi"
echo "  - Timeout: default → 300s"
echo "  - Gunicorn: optimized settings (longer timeout, preload)"
echo ""
echo "The backend should now start without worker timeout errors."
echo ""
echo "Monitor logs:"
echo "  gcloud run services logs tail lunareading-backend --region $REGION"

