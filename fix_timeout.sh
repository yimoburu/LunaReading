#!/bin/bash
# Fix worker timeout and memory issues

REGION=${1:-"us-central1"}

echo "🔧 Fixing Worker Timeout Issues"
echo "================================"
echo ""

echo "1. Increasing memory allocation to 1Gi..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --memory 1Gi \
  --quiet

echo "✅ Memory increased to 1Gi"
echo ""

echo "2. Increasing CPU allocation..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --cpu 2 \
  --quiet

echo "✅ CPU increased to 2"
echo ""

echo "3. Increasing timeout..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --timeout 300 \
  --quiet

echo "✅ Timeout increased to 300 seconds"
echo ""

echo "4. Rebuilding with optimized gunicorn settings..."
# Get backend URL first
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

# Create cloudbuild config
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

echo "5. Redeploying with new settings..."
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --cpu 2 \
  --timeout 300 \
  --max-instances 10 \
  --quiet

echo ""
echo "✅ Configuration updated!"
echo ""
echo "The backend now has:"
echo "  - 1Gi memory (increased from 512Mi)"
echo "  - 2 CPUs (increased from 1)"
echo "  - 300s timeout (increased from default)"
echo "  - Optimized gunicorn settings"
echo ""
echo "Backend URL: $BACKEND_URL"
echo ""
echo "Test the service - it should start faster and handle requests better."

