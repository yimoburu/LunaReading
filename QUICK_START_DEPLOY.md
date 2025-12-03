# Quick Start: Deploy to Google Cloud Run

## Prerequisites

1. Install [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
2. **Option A**: Install [Docker](https://www.docker.com/get-started) (for local builds)
   - **Option B**: Use Cloud Build (no Docker needed!) - see `DEPLOY_WITHOUT_DOCKER.md`
3. Have a Google Cloud account with **billing enabled** ⚠️
   - If you see billing errors, see `ENABLE_BILLING.md` for instructions
   - Google provides $300 free credit for new accounts!

## Step 1: Setup Google Cloud Project

```bash
# Login to Google Cloud
gcloud auth login

# Create project (replace with your project name)
gcloud projects create lunareading-app

# Set as active project
gcloud config set project lunareading-app

# Enable billing (do this in Cloud Console)
# https://console.cloud.google.com/billing
```

## Step 2: Enable Required APIs

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

## Step 3: Set Environment Variables

You'll need to set these when deploying:

- `OPENAI_API_KEY`: Your OpenAI API key
- `JWT_SECRET_KEY`: A random secret for JWT tokens

## Step 4: Deploy

### Option A: Deploy WITHOUT Docker (Recommended if Docker not installed)

```bash
./deploy-no-docker.sh lunareading-app us-central1
```

This uses Cloud Build to build images in the cloud - no local Docker needed!

### Option B: Use the deployment script (requires Docker)

```bash
./deploy.sh lunareading-app us-central1
```

Then set environment variables:
```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')

gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"

gcloud run services update lunareading-frontend \
  --region us-central1 \
  --update-env-vars "BACKEND_URL=$BACKEND_URL"
```

### Option B: Manual deployment

#### Deploy Backend

```bash
# Build image
docker build -t gcr.io/lunareading-app/lunareading-backend -f Dockerfile.backend .

# Push to registry
docker push gcr.io/lunareading-app/lunareading-backend

# Deploy
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
```

#### Deploy Frontend

```bash
# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')

# Build image
docker build -t gcr.io/lunareading-app/lunareading-frontend \
  --build-arg REACT_APP_API_URL=$BACKEND_URL \
  -f Dockerfile.frontend .

# Push to registry
docker push gcr.io/lunareading-app/lunareading-frontend

# Deploy
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"
```

## Step 5: Get Your URLs

```bash
# Backend URL
gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)'

# Frontend URL
gcloud run services describe lunareading-frontend --region us-central1 --format 'value(status.url)'
```

## Step 6: Update Frontend to Use Backend URL

If you didn't set `REACT_APP_API_URL` during build, you can:

1. Update the frontend code to read from environment variable
2. Or rebuild with the backend URL

## Troubleshooting

### Check logs
```bash
gcloud run services logs read lunareading-backend --limit 50
gcloud run services logs read lunareading-frontend --limit 50
```

### Update environment variables
```bash
gcloud run services update lunareading-backend \
  --update-env-vars "KEY=VALUE"
```

### Test locally
```bash
docker build -t lunareading-backend -f Dockerfile.backend .
docker run -p 8080:8080 -e OPENAI_API_KEY=your-key lunareading-backend
```

## Cost

- **Free tier**: 2 million requests/month free
- **After free tier**: ~$0.40 per million requests
- **Estimated cost**: $0-10/month for low-medium traffic

## Next Steps

1. Set up a custom domain (optional)
2. Enable Cloud Monitoring
3. Set up Cloud SQL for production database
4. Configure Secret Manager for API keys

See `DEPLOYMENT.md` for detailed instructions.

