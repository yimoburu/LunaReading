#!/bin/bash
# Fix nginx "upstream sent too big header" error

REGION=${1:-"us-central1"}

echo "🔧 Fixing Nginx Header Buffer Issue"
echo "===================================="
echo ""

echo "The error 'upstream sent too big header' means nginx's buffers are too small."
echo "Updating nginx config to handle larger headers (JWT tokens, cookies, etc.)"
echo ""

echo "1. Rebuilding frontend with updated nginx configuration..."
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

gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-frontend.yaml

echo "✅ Frontend rebuilt"
echo ""

echo "2. Redeploying frontend..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --quiet

echo ""
echo "✅ Frontend redeployed with increased header buffers!"
echo ""
echo "The nginx config now has:"
echo "  - client_header_buffer_size: 4k"
echo "  - large_client_header_buffers: 4 16k"
echo "  - proxy_buffer_size: 4k"
echo "  - proxy_buffers: 4 32k"
echo "  - proxy_busy_buffers_size: 64k"
echo ""
echo "This should fix the 'upstream sent too big header' error."
echo ""
echo "Test login/registration again - it should work now!"

