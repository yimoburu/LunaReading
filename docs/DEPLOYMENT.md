# Deploying LunaReading to Google Cloud

This guide covers deploying the LunaReading application to Google Cloud Platform using Cloud Run.

## Prerequisites

1. **Google Cloud Account**: Sign up at https://cloud.google.com
2. **Google Cloud SDK**: Install from https://cloud.google.com/sdk/docs/install
3. **Docker**: Install Docker Desktop or Docker Engine
4. **Billing**: Enable billing on your Google Cloud project ⚠️ **REQUIRED**
   - If you see "BILLING_NOT_FOUND" errors, see `ENABLE_BILLING.md`
   - Google provides $300 free credit for new accounts (90 days)
   - Enable at: https://console.cloud.google.com/billing

## Setup

### 1. Initialize Google Cloud Project

```bash
# Login to Google Cloud
gcloud auth login

# Create a new project (or use existing)
gcloud projects create lunareading-app --name="LunaReading App"

# Set the project
gcloud config set project lunareading-app

# Enable required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 2. Configure Environment Variables

Create a `.env.production` file with your production secrets:

```bash
OPENAI_API_KEY=your-production-openai-api-key
JWT_SECRET_KEY=your-production-jwt-secret-key
CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
CLOUDSQL_USER=your-username
CLOUDSQL_PASSWORD=your-password
CLOUDSQL_DATABASE=lunareading
```

**Important**: For production:
- **Cloud SQL** is required (SQLite is not supported)
- **Secret Manager** recommended for storing API keys securely

### 3. Update Backend for Cloud Run

The backend needs to:
- Listen on port 8080 (Cloud Run default)
- Use environment variables from Cloud Run

Update `backend/app.py`:

```python
if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=port, debug=False)
```

### 4. Update Frontend Configuration

Update `frontend/package.json` to remove the proxy (since we'll use nginx):

```json
{
  "proxy": "http://localhost:5001"
}
```

Or update the frontend to use the backend URL from environment variables.

## Deployment Options

### Option 1: Cloud Run (Recommended)

Cloud Run is serverless and automatically scales.

#### Build and Deploy Backend

```bash
# Build the Docker image
docker build -t gcr.io/lunareading-app/lunareading-backend -f Dockerfile.backend .

# Push to Container Registry
docker push gcr.io/lunareading-app/lunareading-backend

# Deploy to Cloud Run
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
```

#### Build and Deploy Frontend

```bash
# Build the Docker image
docker build -t gcr.io/lunareading-app/lunareading-frontend -f Dockerfile.frontend .

# Push to Container Registry
docker push gcr.io/lunareading-app/lunareading-frontend

# Deploy to Cloud Run
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 80
```

#### Update Frontend to Use Backend URL

After deploying, get the backend URL:
```bash
gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)'
```

Update `nginx.conf` to proxy to this URL, or set it as an environment variable in the frontend.

### Option 2: Using Cloud Build (CI/CD)

For automated deployments:

```bash
# Submit build to Cloud Build
gcloud builds submit --config cloudbuild.yaml

# Or connect to GitHub for automatic builds
gcloud builds triggers create github \
  --repo-name=lunareading \
  --repo-owner=your-username \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

### Option 3: App Engine (Alternative)

```bash
# Deploy to App Engine
gcloud app deploy app.yaml

# Set environment variables
gcloud app deploy --set-env-vars OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret
```

## Using Secret Manager (Recommended for Production)

Store sensitive data securely:

```bash
# Create secrets
echo -n "your-openai-api-key" | gcloud secrets create openai-api-key --data-file=-
echo -n "your-jwt-secret" | gcloud secrets create jwt-secret-key --data-file=-

# Grant Cloud Run access
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

Update Cloud Run service to use secrets:
```bash
gcloud run services update lunareading-backend \
  --update-secrets OPENAI_API_KEY=openai-api-key:latest,JWT_SECRET_KEY=jwt-secret-key:latest
```

## Database Setup

### Option 1: Cloud SQL (Recommended for Production)

```bash
# Create Cloud SQL instance
gcloud sql instances create lunareading-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database
gcloud sql databases create lunareading --instance=lunareading-db

# Update connection string in app.py
# Cloud SQL connection variables:
# CLOUDSQL_INSTANCE_CONNECTION_NAME = "project:region:instance"
# CLOUDSQL_USER = "user"
# CLOUDSQL_PASSWORD = "password"
# CLOUDSQL_DATABASE = "lunareading"
```

### Option 2: Cloud Storage for SQLite (Simple)

Mount Cloud Storage bucket for SQLite file persistence.

## Post-Deployment

1. **Get Service URLs**:
   ```bash
   gcloud run services list
   ```

2. **Update CORS** (if needed):
   - Backend CORS is already configured for `*`, but you can restrict it to your frontend domain

3. **Monitor Logs**:
   ```bash
   gcloud run services logs read lunareading-backend --limit 50
   ```

4. **Set Up Custom Domain** (optional):
   ```bash
   gcloud run domain-mappings create \
     --service lunareading-frontend \
     --domain yourdomain.com
   ```

## Cost Estimation

- **Cloud Run**: Pay per request (~$0.40 per million requests)
- **Cloud SQL**: ~$7-25/month for db-f1-micro
- **Container Registry**: ~$0.026/GB/month
- **Total**: ~$10-30/month for low traffic

## Troubleshooting

### Check logs
```bash
gcloud run services logs read lunareading-backend --limit 100
```

### Test locally with Docker
```bash
docker build -t lunareading-backend -f Dockerfile.backend .
docker run -p 8080:8080 -e OPENAI_API_KEY=your-key lunareading-backend
```

### Update environment variables
```bash
gcloud run services update lunareading-backend \
  --update-env-vars KEY=VALUE
```

## Security Best Practices

1. ✅ Use Secret Manager for API keys
2. ✅ Enable Cloud Armor for DDoS protection
3. ✅ Use Cloud SQL with private IP
4. ✅ Enable Cloud Run authentication (remove `--allow-unauthenticated`)
5. ✅ Set up Cloud Monitoring and Alerting
6. ✅ Use HTTPS (automatic with Cloud Run)

