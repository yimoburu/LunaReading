# Deploy to Google Cloud Without Local Docker

You can deploy to Google Cloud Run using **Cloud Build**, which builds your containers in the cloud - no local Docker needed!

## Prerequisites

1. ✅ Google Cloud SDK installed
2. ✅ Billing enabled (see `ENABLE_BILLING.md`)
3. ✅ APIs enabled (see below)

## Step 1: Enable Required APIs

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## Step 2: Deploy Using Cloud Build

Cloud Build will build your Docker images in the cloud and deploy them automatically.

### Deploy Backend

```bash
# Submit build to Cloud Build
gcloud builds submit --tag gcr.io/lunareading-app/lunareading-backend \
  --config=cloudbuild-backend.yaml

# Or build and deploy in one step
gcloud builds submit --tag gcr.io/lunareading-app/lunareading-backend \
  --file=Dockerfile.backend .

# Deploy to Cloud Run
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
```

### Deploy Frontend

```bash
# Build frontend
gcloud builds submit --tag gcr.io/lunareading-app/lunareading-frontend \
  --file=Dockerfile.frontend .

# Get backend URL first
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region us-central1 --format 'value(status.url)')

# Deploy frontend
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"
```

## Step 3: Using Cloud Build Config (Automated)

Create a simplified Cloud Build config that builds and deploys:

```bash
# This will build both services and deploy them
gcloud builds submit --config=cloudbuild.yaml
```

## Alternative: Use App Engine (No Docker at All)

App Engine can deploy Python apps directly without Docker:

```bash
# Deploy backend to App Engine
gcloud app deploy app.yaml

# Set environment variables
gcloud app deploy --set-env-vars \
  "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
```

**Note:** App Engine requires some modifications to the app structure. See `DEPLOYMENT.md` for details.

## Quick Deploy Script (No Docker)

Save this as `deploy-no-docker.sh`:

```bash
#!/bin/bash
PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🚀 Deploying without local Docker using Cloud Build..."

# Build and deploy backend
echo "Building backend..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/lunareading-backend \
  --file=Dockerfile.backend . --region=$REGION

echo "Deploying backend..."
gcloud run deploy lunareading-backend \
  --image gcr.io/$PROJECT_ID/lunareading-backend \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080

# Build and deploy frontend
echo "Building frontend..."
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region $REGION --format 'value(status.url)')

gcloud builds submit --tag gcr.io/$PROJECT_ID/lunareading-frontend \
  --file=Dockerfile.frontend . --region=$REGION

echo "Deploying frontend..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/$PROJECT_ID/lunareading-frontend \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"

echo "✅ Deployment complete!"
echo "Backend: $BACKEND_URL"
echo "Frontend: $(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)')"
```

Make it executable and run:
```bash
chmod +x deploy-no-docker.sh
./deploy-no-docker.sh lunareading-app us-central1
```

## Advantages of Cloud Build

✅ No local Docker installation needed
✅ Builds happen in Google's infrastructure (faster)
✅ Automatic caching and optimization
✅ Can trigger on Git commits (CI/CD)
✅ Free tier: 120 build-minutes/day

## Cost

- **Cloud Build**: 120 build-minutes/day free, then $0.003/minute
- **Cloud Run**: Same pricing as regular deployment
- **Total**: Essentially free for small projects

## Next Steps

1. ✅ Enable billing (if not done)
2. ✅ Enable APIs
3. ✅ Run the deployment commands above
4. ✅ Set environment variables
5. ✅ Access your deployed app!

