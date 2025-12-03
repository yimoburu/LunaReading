# Rebuild Instructions

## Quick Rebuild (Both Services)

```bash
./rebuild_all.sh us-central1
```

## Manual Rebuild Steps

### 1. Rebuild Backend

```bash
# Build backend image
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

gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=us-central1
rm /tmp/cloudbuild-backend.yaml

# Redeploy backend
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --timeout 300 \
  --quiet
```

### 2. Get Backend URL and Set for Frontend

```bash
# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')

# Set BACKEND_URL for frontend
gcloud run services update lunareading-frontend \
  --region us-central1 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet
```

### 3. Rebuild Frontend

```bash
# Build frontend image
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

gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=us-central1
rm /tmp/cloudbuild-frontend.yaml

# Redeploy frontend
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --timeout 300 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL" \
  --quiet
```

## What Gets Rebuilt

### Backend
- Uses `Dockerfile.backend`
- Includes Flask app with Gunicorn
- Database initialization
- All Python dependencies

### Frontend
- Uses `Dockerfile.frontend`
- React app build
- Nginx with custom entrypoint
- Updated `nginx.conf.template` with fixed proxy configuration

## After Rebuild

The script will:
1. Rebuild both Docker images
2. Redeploy both services
3. Set BACKEND_URL for frontend
4. Test both services
5. Show service URLs

## Troubleshooting

If rebuild fails:
1. Check gcloud is authenticated: `gcloud auth list`
2. Check project is set: `gcloud config get-value project`
3. Check billing is enabled
4. Check Cloud Build API is enabled

