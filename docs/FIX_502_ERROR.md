# Fixing 502 Bad Gateway Error on Google Cloud Run

A 502 error means the backend is receiving requests but failing to process them. Here are common causes and fixes:

## Common Causes

### 1. Database File Permissions (Most Likely)

SQLite needs write permissions. In Cloud Run, the filesystem is read-only except for `/tmp`.

**Fix**: Use `/tmp` for SQLite database or switch to Cloud SQL.

### 2. Missing Environment Variables

The app might be crashing because required env vars aren't set.

**Fix**: Set environment variables:
```bash
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret,SQLALCHEMY_DATABASE_URI=sqlite:////tmp/lunareading.db"
```

### 3. App Crashing on Startup

Check logs to see what's failing:
```bash
gcloud run services logs read lunareading-backend --region us-central1 --limit 100
```

### 4. Timeout Issues

Cloud Run has default timeouts. Increase if needed:
```bash
gcloud run services update lunareading-backend \
  --region us-central1 \
  --timeout=300
```

## Quick Fix: Use /tmp for Database

The easiest fix is to use `/tmp` directory which is writable in Cloud Run:

```bash
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "SQLALCHEMY_DATABASE_URI=sqlite:////tmp/lunareading.db"
```

**Note**: Data in `/tmp` is lost when the container restarts. For production, use Cloud SQL.

## Check Logs

```bash
# View recent logs
gcloud run services logs read lunareading-backend --region us-central1 --limit 50

# Follow logs in real-time
gcloud run services logs tail lunareading-backend --region us-central1
```

Look for:
- Permission errors
- Database errors
- Import errors
- Missing environment variables

## Test Backend Directly

```bash
# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')

# Test health endpoint
curl $BACKEND_URL/

# Test registration (should fail with proper error, not 502)
curl -X POST $BACKEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123","grade_level":3}'
```

