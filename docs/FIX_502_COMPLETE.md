# Complete Fix for 502 Error

A 502 Bad Gateway error means the frontend can't reach the backend. Here's how to fix it:

## Root Causes

1. **Frontend doesn't know backend URL** - Most common issue
2. **Backend not running/crashing** - Check logs
3. **Database permissions** - SQLite needs writable directory
4. **Missing environment variables** - Backend needs API keys

## Quick Fix (Run This Script)

```bash
./fix_502_error.sh us-central1
```

This script will:
- ✅ Update database path to `/tmp` (writable in Cloud Run)
- ✅ Set JWT secret key if missing
- ✅ Configure frontend to point to backend
- ✅ Test backend connectivity

## Manual Fix Steps

### Step 1: Fix Backend Database Path

```bash
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance,CLOUDSQL_USER=user,CLOUDSQL_PASSWORD=password,CLOUDSQL_DATABASE=lunareading"
```

### Step 2: Set Required Environment Variables

```bash
# Set OpenAI API key
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "OPENAI_API_KEY=your-actual-key"

# Set JWT secret (generate if needed)
JWT_SECRET=$(openssl rand -hex 32)
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "JWT_SECRET_KEY=$JWT_SECRET"
```

### Step 3: Get Backend URL and Update Frontend

```bash
# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region us-central1 --format 'value(status.url)')

# Update frontend to use backend URL
gcloud run services update lunareading-frontend \
  --region us-central1 \
  --update-env-vars "BACKEND_URL=$BACKEND_URL"
```

### Step 4: Rebuild Frontend with Backend URL

The frontend needs to be rebuilt with the backend URL. Update the Dockerfile to inject it:

```bash
# Rebuild frontend with backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region us-central1 --format 'value(status.url)')

# Create temporary cloudbuild config
cat > /tmp/cloudbuild-frontend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '--build-arg'
    - 'REACT_APP_API_URL=$BACKEND_URL'
    - '-t'
    - 'gcr.io/lunareading-app/lunareading-frontend:latest'
    - '-f'
    - 'Dockerfile.frontend'
    - '.'
images:
- 'gcr.io/lunareading-app/lunareading-frontend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=us-central1

# Redeploy frontend
gcloud run deploy lunareading-frontend \
  --image gcr.io/lunareading-app/lunareading-frontend:latest \
  --region us-central1
```

## Alternative: Use Nginx Proxy (Current Setup)

If using nginx proxy in frontend container:

1. Make sure BACKEND_URL is set in frontend service
2. Nginx will proxy `/api` requests to backend
3. Frontend should use relative URLs (already configured)

## Check Backend Logs

```bash
gcloud run services logs read lunareading-backend --region us-central1 --limit 50
```

Look for:
- Database permission errors
- Missing environment variables
- Import errors
- Startup errors

## Test Backend Directly

```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region us-central1 --format 'value(status.url)')

# Test health endpoint
curl $BACKEND_URL/

# Test registration
curl -X POST $BACKEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123","grade_level":3}'
```

If this works, the backend is fine and the issue is frontend configuration.

## Verify Frontend Configuration

The frontend should:
1. Use relative URLs (`/api/...`) if nginx is proxying
2. Or use the full backend URL if calling directly

Check browser console (F12) for the actual API URL being used.

