# Fix Cloud SQL Connection on Cloud Run

## Problem

When deploying the backend to Google Cloud Run, the application cannot connect to Cloud SQL even though:
- Local deployment works fine
- Health check passes (app starts successfully)
- Environment variables are set correctly

## Root Cause

Cloud Run requires the Cloud SQL instance to be **explicitly added** to the service using the `--add-cloudsql-instances` flag. Without this, Cloud Run cannot establish a network connection to the Cloud SQL instance, even though the Cloud SQL Connector library is installed.

## Solution

### Automatic Fix (Recommended)

The deployment script (`deploy-no-docker.sh`) has been updated to automatically:
1. Extract `CLOUDSQL_INSTANCE_CONNECTION_NAME` from your `.env` file
2. Add the Cloud SQL instance to the Cloud Run service using `--add-cloudsql-instances`
3. Provide instructions for granting service account permissions

**Simply redeploy:**
```bash
./deploy-no-docker.sh PROJECT_ID REGION
```

### Manual Fix for Existing Deployment

If you already have a deployment that's not connecting:

**Option 1: Use the fix script**
```bash
./scripts/fix_cloudsql_connection.sh PROJECT_ID REGION
```

**Option 2: Manual steps**

1. **Add Cloud SQL instance to service:**
   ```bash
   gcloud run services update lunareading-backend \
     --region REGION \
     --add-cloudsql-instances PROJECT:REGION:INSTANCE
   ```

2. **Grant service account permissions:**
   ```bash
   # Get the service account
   SERVICE_ACCOUNT=$(gcloud run services describe lunareading-backend \
     --region REGION \
     --format 'value(spec.template.spec.serviceAccountName)')
   
   # Grant Cloud SQL Client role
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="serviceAccount:${SERVICE_ACCOUNT}" \
     --role="roles/cloudsql.client"
   ```

3. **Verify environment variables are set:**
   ```bash
   gcloud run services describe lunareading-backend \
     --region REGION \
     --format 'value(spec.template.spec.containers[0].env)'
   ```

## Why This Happens

### Local Development
- Uses Cloud SQL Proxy via the Cloud SQL Connector
- Authenticates using your local Google Cloud credentials
- Works automatically with proper IAM permissions

### Cloud Run Deployment
- Requires explicit network connection setup
- The `--add-cloudsql-instances` flag creates a Unix socket at `/cloudsql/INSTANCE_CONNECTION_NAME`
- The Cloud SQL Connector can then use this socket for secure connections
- Service account must have `roles/cloudsql.client` role

## Verification

After applying the fix:

1. **Check service configuration:**
   ```bash
   gcloud run services describe lunareading-backend \
     --region REGION \
     --format 'value(spec.template.spec.containers[0].env,spec.template.metadata.annotations)'
   ```
   Look for `run.googleapis.com/cloudsql-instances` annotation.

2. **Check logs:**
   ```bash
   gcloud run services logs read lunareading-backend \
     --region REGION \
     --limit 50
   ```
   Look for "✅ Cloud SQL connection successful" message.

3. **Test the connection:**
   ```bash
   curl https://YOUR-BACKEND-URL/api/health
   ```

## Common Issues

### Issue: "Permission denied" errors
**Solution:** Grant the service account the `roles/cloudsql.client` role (see manual fix step 2 above).

### Issue: "Connection refused" errors
**Solution:** 
- Verify the Cloud SQL instance is running: `gcloud sql instances list`
- Ensure the instance is in the same region as Cloud Run (or use private IP)
- Check that `--add-cloudsql-instances` was applied correctly

### Issue: Instance already added
**Solution:** If you see "already exists" error, the instance is already configured. Check logs for other connection issues.

## Prevention

The updated `deploy-no-docker.sh` script now automatically:
- ✅ Extracts Cloud SQL instance from `.env`
- ✅ Adds instance to Cloud Run service
- ✅ Provides clear instructions for permissions

Make sure your `.env` file contains:
```bash
CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
CLOUDSQL_USER=your-username
CLOUDSQL_PASSWORD=your-password
CLOUDSQL_DATABASE=lunareading
```

## Related Files

- `deploy-no-docker.sh` - Main deployment script (now includes Cloud SQL setup)
- `scripts/fix_cloudsql_connection.sh` - Fix script for existing deployments
- `cloudbuild.yaml` - Cloud Build config (needs manual Cloud SQL instance configuration)
- `backend/cloudsql_client.py` - Cloud SQL Connector client implementation

