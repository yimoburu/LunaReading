# Fix Cloud Run Startup Issues After MySQL Migration

## Problem

After migrating to Cloud SQL MySQL, the Cloud Run container fails to start with:
```
The user-provided container failed to start and listen on the port defined provided by the PORT=8080 environment variable within the allocated timeout.
```

## Common Causes

1. **Missing MySQL Dependencies**: `pymysql` and `sqlalchemy` not installed in container
2. **Database Connection Error**: Can't connect to Cloud SQL on startup
3. **Cloud SQL Not Connected**: Instance not added to Cloud Run service
4. **Incorrect Connection String**: Wrong format or credentials

## Solution

### Step 1: Rebuild Backend with MySQL Dependencies

The backend Docker image needs to be rebuilt to include `pymysql` and `sqlalchemy`:

```bash
./scripts/fix_mysql_startup.sh us-central1
```

This script will:
- Rebuild the backend image with updated `requirements.txt`
- Update Cloud Run service with MySQL connection
- Check service status

### Step 2: Manual Rebuild (Alternative)

If the script doesn't work, rebuild manually:

```bash
# Build backend image
cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'build'
    - '-t'
    - 'gcr.io/PROJECT_ID/lunareading-backend:latest'
    - '-f'
    - 'Dockerfile.backend'
    - '.'
images:
- 'gcr.io/PROJECT_ID/lunareading-backend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=us-central1
rm /tmp/cloudbuild-backend.yaml

# Deploy with updated image
gcloud run deploy lunareading-backend \
  --image gcr.io/PROJECT_ID/lunareading-backend:latest \
  --region us-central1
```

### Step 3: Verify Requirements

Check that `requirements.txt` includes:
```
pymysql==1.1.0
sqlalchemy==2.0.23
```

### Step 4: Check Connection String

Verify the connection string format:
```
mysql+pymysql://USER:PASSWORD@/DATABASE?unix_socket=/cloudsql/CONNECTION_NAME
```

Where `CONNECTION_NAME` is: `PROJECT_ID:REGION:INSTANCE_NAME`

### Step 5: Check Cloud SQL Connection

Verify Cloud SQL instance is added to the service:

```bash
gcloud run services describe lunareading-backend \
  --region us-central1 \
  --format="yaml(spec.template.spec.containers[0].cloudSqlInstances)"
```

Should show your Cloud SQL instance connection name.

### Step 6: Check Logs

View detailed error logs:

```bash
gcloud run services logs read lunareading-backend \
  --region us-central1 \
  --limit 100
```

Look for:
- `ModuleNotFoundError: No module named 'pymysql'` → Rebuild needed
- `Can't connect to MySQL server` → Connection issue
- `Access denied` → Wrong credentials
- `Unknown database` → Database doesn't exist

## Troubleshooting

### Error: "No module named 'pymysql'"

**Solution**: Rebuild the Docker image. The `requirements.txt` has been updated, but the image needs to be rebuilt.

```bash
./scripts/fix_mysql_startup.sh us-central1
```

### Error: "Can't connect to MySQL server"

**Possible causes**:
1. Cloud SQL instance not added to service
2. Wrong connection name
3. Service account doesn't have Cloud SQL Client role

**Solution**:
```bash
# Add Cloud SQL instance
gcloud run services update lunareading-backend \
  --region us-central1 \
  --add-cloudsql-instances PROJECT:REGION:INSTANCE

# Grant permissions
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

### Error: "Access denied for user"

**Solution**: Verify database user and password:
```bash
# Check saved password
cat .cloudsql_user_password

# Reset password if needed
gcloud sql users set-password USER \
  --instance=INSTANCE \
  --password=NEW_PASSWORD
```

### Error: "Unknown database"

**Solution**: Create the database:
```bash
gcloud sql databases create lunareading --instance=INSTANCE
```

### Database Initialization Fails

The updated code now handles MySQL connection errors gracefully. If the database isn't ready on startup, it will retry on the first request.

However, if you see persistent errors, check:
1. Cloud SQL instance is running
2. Database exists
3. User has proper permissions
4. Connection string is correct

## Verification

After fixing, verify the service starts:

```bash
# Check service URL
gcloud run services describe lunareading-backend \
  --region us-central1 \
  --format="value(status.url)"

# Test endpoint
curl https://YOUR-SERVICE-URL/
```

Should return: `{"message": "LunaReading API Server"}`

## Rollback to SQLite (If Needed)

If you need to rollback temporarily:

```bash
gcloud run services update lunareading-backend \
  --region us-central1 \
  --update-env-vars "SQLALCHEMY_DATABASE_URI=sqlite:////tmp/lunareading.db" \
  --remove-cloudsql-instances PROJECT:REGION:INSTANCE
```

## Prevention

To avoid this issue in the future:
1. ✅ Always rebuild after updating `requirements.txt`
2. ✅ Test database connection before deploying
3. ✅ Use the provided scripts for setup
4. ✅ Check logs after deployment

