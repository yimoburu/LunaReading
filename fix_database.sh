#!/bin/bash
# Fix database initialization issue

REGION=${1:-"us-central1"}

echo "🔧 Fixing Database Initialization"
echo "==================================="
echo ""

echo "The error shows database tables don't exist."
echo "This happens when db.create_all() isn't called properly."
echo ""

echo "1. Rebuilding backend with database initialization fix..."
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

echo "2. Redeploying backend..."
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
echo "✅ Backend redeployed!"
echo ""
echo "The database will now be initialized on startup."
echo ""
echo "Test registration again - it should work now."
echo ""
echo "If it still fails, check logs:"
echo "  gcloud run services logs read lunareading-backend --region $REGION --limit 50"

