# Backend Server Database Connection Troubleshooting

## Problem
Direct database queries work (using `CloudSQLClient` directly), but queries through the backend server HTTP API don't work.

## Common Causes and Solutions

### 1. Cloud SQL Instance Not Attached to Cloud Run Service ⚠️ **MOST COMMON**

**Symptom:** Backend can't connect to database, but direct connection works.

**Cause:** Cloud Run service doesn't have the Cloud SQL instance attached via annotations.

**Solution:**
```bash
# Get the instance connection name from environment variables
INSTANCE_NAME=$(gcloud run services describe lunareading-backend \
  --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)' | \
  python3 -c "import sys, re; data=sys.stdin.read(); match=re.search(r\"\{'name':\s*'CLOUDSQL_INSTANCE_CONNECTION_NAME',\s*'value':\s*'([^']+)'\", data); print(match.group(1) if match else '')")

# Add the instance to the Cloud Run service
gcloud run services update lunareading-backend \
  --region us-central1 \
  --add-cloudsql-instances $INSTANCE_NAME
```

**Verify:**
```bash
gcloud run services describe lunareading-backend \
  --region us-central1 \
  --format='value(spec.template.metadata.annotations."run.googleapis.com/cloudsql-instances")'
```

### 2. Service Account Missing Cloud SQL Client Permission

**Symptom:** Connection attempts fail with permission errors.

**Cause:** The service account running Cloud Run doesn't have `roles/cloudsql.client` permission.

**Solution:**
```bash
# Get the service account
SERVICE_ACCOUNT=$(gcloud run services describe lunareading-backend \
  --region us-central1 \
  --format 'value(spec.template.spec.serviceAccountName)')

# If empty, use default compute service account
if [ -z "$SERVICE_ACCOUNT" ]; then
  PROJECT_NUMBER=$(gcloud projects describe lunareading-app --format 'value(projectNumber)')
  SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
fi

# Grant permission
gcloud projects add-iam-policy-binding lunareading-app \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client"
```

### 3. Missing or Incorrect Environment Variables

**Symptom:** Backend can't find database connection parameters.

**Cause:** Environment variables not set or incorrect in Cloud Run service.

**Solution:**
```bash
# Check current environment variables
gcloud run services describe lunareading-backend \
  --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)'

# Update environment variables
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance,CLOUDSQL_DATABASE=database,CLOUDSQL_USER=user,CLOUDSQL_PASSWORD=password"
```

### 4. Database Client Not Initialized

**Symptom:** `db_client` is `None` in routes, causing queries to fail.

**Cause:** Database client initialization failed during app startup.

**Check logs:**
```bash
gcloud run services logs read lunareading-backend \
  --region us-central1 \
  --limit 100 | grep -i "cloud sql\|database\|connection"
```

**Look for:**
- "Cloud SQL connection successful" ✅
- "Cloud SQL connection failed" ❌
- "Database client not initialized" ❌

**Solution:** Fix the underlying connection issue (usually #1 or #2 above).

### 5. Connection Timeout

**Symptom:** Queries hang or timeout.

**Cause:** Network connectivity issues or Cloud SQL instance not accessible.

**Check:**
```bash
# Check Cloud SQL instance status
gcloud sql instances describe <instance-id> --format='value(state)'
# Should be: RUNNABLE

# Check backend logs for timeout errors
gcloud run services logs read lunareading-backend \
  --region us-central1 \
  --limit 100 | grep -i "timeout\|connection"
```

### 6. Database User Permissions

**Symptom:** Connection succeeds but queries fail with permission errors.

**Cause:** Database user doesn't have required permissions.

**Solution:** Grant necessary permissions to the database user:
```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON database_name.* TO 'user'@'%';
FLUSH PRIVILEGES;
```

### 7. Different Connection Methods

**Symptom:** Direct connection uses IP, but Cloud Run needs Unix socket.

**Cause:** Cloud SQL Connector uses different connection methods in different environments.

**Note:** The `google.cloud.sql.connector` library automatically handles this, but ensure:
- Cloud SQL instance has private IP enabled (for Cloud Run)
- Or public IP with authorized networks (less secure)

## Diagnostic Script

Run the comprehensive diagnostic script:

```bash
./scripts/diagnose_backend_db_issues.sh
```

This will check all common issues and provide specific fixes.

## Quick Fix Script

Run the automated fix script:

```bash
./scripts/fix_backend_database_connection.sh
```

This script will:
1. Grant Cloud SQL Client permission to service account
2. Add Cloud SQL instance to Cloud Run service
3. Verify environment variables
4. Test backend connection

## Testing

After fixing issues, test the connection:

```bash
# Test database status endpoint
curl https://your-backend-url/api/db-status

# Test through Python script
python3 scripts/test_database_queries.py https://your-backend-url
```

## Why Direct Queries Work But Backend Doesn't

1. **Local vs Cloud Run Environment:**
   - Local: Uses your user credentials and direct network access
   - Cloud Run: Uses service account and requires Cloud SQL instance attachment

2. **Authentication:**
   - Local: Your gcloud credentials
   - Cloud Run: Service account with IAM permissions

3. **Network:**
   - Local: Direct network connection
   - Cloud Run: Requires Cloud SQL proxy/connector via Unix socket

4. **Initialization:**
   - Direct: You control when connection is made
   - Backend: Connection must be established during app startup

## Common Error Messages

| Error | Likely Cause | Solution |
|-------|-------------|----------|
| "Database client not initialized" | Connection failed at startup | Check logs, fix connection issue |
| "Connection refused" | Instance not attached | Add `--add-cloudsql-instances` |
| "Permission denied" | Missing IAM role | Grant `roles/cloudsql.client` |
| "Access denied for user" | Wrong credentials | Check environment variables |
| "Connection timeout" | Network issue | Check instance status, firewall rules |

