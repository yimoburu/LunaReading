#!/bin/bash
# Quick deployment script for Google Cloud Run

set -e

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🚀 Deploying LunaReading to Google Cloud Run"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker."
    exit 1
fi

# Set project
echo "📋 Setting Google Cloud project..."
gcloud config set project $PROJECT_ID

# Enable APIs
echo "🔧 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build and push backend
echo "🏗️  Building backend Docker image..."
docker build -t gcr.io/$PROJECT_ID/lunareading-backend:latest -f Dockerfile.backend .

echo "📤 Pushing backend image..."
docker push gcr.io/$PROJECT_ID/lunareading-backend:latest

# Build and push frontend
echo "🏗️  Building frontend Docker image..."
docker build -t gcr.io/$PROJECT_ID/lunareading-frontend:latest -f Dockerfile.frontend .

echo "📤 Pushing frontend image..."
docker push gcr.io/$PROJECT_ID/lunareading-frontend:latest

# Deploy backend
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
  --set-env-vars "CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance,CLOUDSQL_USER=user,CLOUDSQL_PASSWORD=password,CLOUDSQL_DATABASE=lunareading" || {
    echo "⚠️  Backend deployment failed. You may need to set environment variables manually:"
    echo "   gcloud run services update lunareading-backend --update-env-vars CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance,CLOUDSQL_USER=user,CLOUDSQL_PASSWORD=password,CLOUDSQL_DATABASE=lunareading"
}

# Deploy frontend
echo "🚀 Deploying frontend to Cloud Run..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/$PROJECT_ID/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --cpu 1 \
  --max-instances 10

# Get service URLs
echo ""
echo "✅ Deployment complete!"
echo ""
echo "Backend URL:"
gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)'
echo ""
echo "Frontend URL:"
gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)'
echo ""
echo "📝 Next steps:"
echo "1. Set environment variables for backend:"
echo "   gcloud run services update lunareading-backend --update-env-vars OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
echo ""
echo "2. Update frontend nginx.conf to point to backend URL"
echo "3. Redeploy frontend if nginx config changed"

