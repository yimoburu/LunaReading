#!/bin/bash
# Deploy to Google Cloud Run without requiring local Docker
# Uses Cloud Build to build images in the cloud

set -e

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🚀 Deploying LunaReading to Google Cloud Run (No Local Docker Required)"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Set project
echo "📋 Setting Google Cloud project..."
gcloud config set project $PROJECT_ID

# Enable APIs
echo "🔧 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com --quiet || true
gcloud services enable run.googleapis.com --quiet || true
gcloud services enable artifactregistry.googleapis.com --quiet || true

# Build and deploy backend
echo ""
echo "🏗️  Building backend using Cloud Build..."

# Create temporary cloudbuild config for backend
cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/lunareading-backend:latest', '-f', 'Dockerfile.backend', '.']
images:
- 'gcr.io/$PROJECT_ID/lunareading-backend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-backend.yaml

echo "🚀 Deploying backend to Cloud Run..."
gcloud run deploy lunareading-backend \
  --image gcr.io/$PROJECT_ID/lunareading-backend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars "SQLALCHEMY_DATABASE_URI=sqlite:////tmp/lunareading.db" || {
    echo "⚠️  Backend deployed. Set environment variables:"
    echo "   gcloud run services update lunareading-backend --update-env-vars OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
}

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Failed to get backend URL"
    exit 1
fi

echo "✅ Backend URL: $BACKEND_URL"

# Build and deploy frontend
echo ""
echo "🏗️  Building frontend using Cloud Build..."

# Create temporary cloudbuild config for frontend
cat > /tmp/cloudbuild-frontend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/lunareading-frontend:latest', '-f', 'Dockerfile.frontend', '.']
images:
- 'gcr.io/$PROJECT_ID/lunareading-frontend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-frontend.yaml

echo "🚀 Deploying frontend to Cloud Run..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/$PROJECT_ID/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"

# Get service URLs
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Service URLs:"
echo "Backend:  $BACKEND_URL"
FRONTEND_URL=$(gcloud run services describe lunareading-frontend \
  --region $REGION --format 'value(status.url)')
echo "Frontend: $FRONTEND_URL"
echo ""
echo "📝 Next steps:"
echo "1. Set environment variables for backend:"
echo "   gcloud run services update lunareading-backend \\"
echo "     --region $REGION \\"
echo "     --update-env-vars \"OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret\""
echo ""
echo "2. Update frontend config if needed"
echo "3. Test your deployment!"

