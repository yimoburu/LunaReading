# Database Connection Setup Guide

This guide explains how to configure Cloud SQL connection using Google Cloud SQL Connector.

## Quick Setup

### Automatic Setup (Recommended)

**For Cloud SQL (Production):**
```bash
# Set up Cloud SQL instance (if not already done)
./scripts/setup_cloud_sql.sh

# Configure connection in .env file manually
# See environment variables below
```

**To view current connection info:**
```bash
grep CLOUDSQL .env
```

## Environment Variables

### Required Variables

Set these in your `.env` file:

```bash
# Cloud SQL instance connection name (format: project:region:instance)
CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance

# Database credentials
CLOUDSQL_USER=your-username
CLOUDSQL_PASSWORD=your-password

# Database name (optional, defaults to 'lunareading')
CLOUDSQL_DATABASE=lunareading
```

### Getting Connection Information

**Instance Connection Name:**
```bash
# Get connection name
gcloud sql instances describe INSTANCE_NAME --format='value(connectionName)'

# Format: project:region:instance
# Example: lunareading-app:us-central1:lunareading-db
```

**User and Password:**
- Check `.cloudsql_user_password` file (if exists from previous setup)
- Or create new user:
  ```bash
  gcloud sql users create USERNAME --instance=INSTANCE_NAME --password=PASSWORD
  ```

**Database:**
- Usually `lunareading`
- Create if doesn't exist:
  ```bash
  gcloud sql databases create lunareading --instance=INSTANCE_NAME
  ```

## Connection Methods

### Cloud Run (Production)

On Cloud Run, the Cloud SQL Connector automatically handles connections:

1. **Add Cloud SQL instance to Cloud Run service:**
   ```bash
   gcloud run services update SERVICE_NAME \
     --add-cloudsql-instances=INSTANCE_CONNECTION_NAME \
     --region=REGION
   ```

2. **Set environment variables:**
   ```bash
   gcloud run services update SERVICE_NAME \
     --update-env-vars="CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance,CLOUDSQL_USER=user,CLOUDSQL_PASSWORD=password,CLOUDSQL_DATABASE=lunareading" \
     --region=REGION
   ```

### Local Development

For local development, you have two options:

#### Option 1: Cloud SQL Proxy (Recommended)

1. **Install Cloud SQL Proxy:**
   - Download from: https://cloud.google.com/sql/docs/mysql/sql-proxy
   - Or use: `gcloud components install cloud-sql-proxy`

2. **Start proxy:**
   ```bash
   cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306
   ```

3. **Set environment variables in .env:**
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
   CLOUDSQL_USER=user
   CLOUDSQL_PASSWORD=password
   CLOUDSQL_DATABASE=lunareading
   ```

#### Option 2: Application Default Credentials

1. **Set up Application Default Credentials:**
   ```bash
   gcloud auth application-default login
   ```

2. **Set environment variables in .env:**
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
   CLOUDSQL_USER=user
   CLOUDSQL_PASSWORD=password
   CLOUDSQL_DATABASE=lunareading
   ```

## Authentication

The Cloud SQL Connector uses Application Default Credentials (ADC):

1. **For local development:**
   ```bash
   gcloud auth application-default login
   ```

2. **For Cloud Run:**
   - Uses the service account attached to the Cloud Run service
   - Ensure service account has `roles/cloudsql.client` role

3. **For service account:**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
   ```

## Verification

### Test Connection

1. **Check environment variables:**
   ```bash
   grep CLOUDSQL .env
   ```

2. **Run application:**
   ```bash
   python run_backend.py
   ```

3. **Check logs:**
   - Should see: "✅ Cloud SQL connection successful"
   - Should see: "✅ Database tables created/verified successfully"

### Common Issues

#### "CLOUDSQL_INSTANCE_CONNECTION_NAME is required"
- **Solution:** Set `CLOUDSQL_INSTANCE_CONNECTION_NAME` in `.env` file

#### "CLOUDSQL_USER is required"
- **Solution:** Set `CLOUDSQL_USER` in `.env` file

#### "CLOUDSQL_PASSWORD is required"
- **Solution:** Set `CLOUDSQL_PASSWORD` in `.env` file

#### "Authentication failed"
- **Solution:** Run `gcloud auth application-default login` or set `GOOGLE_APPLICATION_CREDENTIALS`

#### "Permission denied"
- **Solution:** Grant `roles/cloudsql.client` to service account:
  ```bash
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:SERVICE_ACCOUNT" \
    --role="roles/cloudsql.client"
  ```

## Security Best Practices

1. **Never commit credentials:**
   - Keep `.env` file out of version control
   - Use Cloud Run secrets for production

2. **Use service accounts:**
   - Prefer service accounts over user credentials
   - Grant minimum necessary permissions

3. **Rotate passwords:**
   - Regularly update database passwords
   - Update environment variables accordingly

4. **Use secrets management:**
   - For production, use Cloud Run secrets:
     ```bash
     gcloud run services update SERVICE_NAME \
       --update-secrets=CLOUDSQL_PASSWORD=db-password:latest \
       --region=REGION
     ```

## Summary

- ✅ Use Cloud SQL Connector for secure connections
- ✅ Set required environment variables
- ✅ Use Application Default Credentials for authentication
- ✅ Test connection before deploying

For more details, see:
- `docs/CLOUDSQL_CONNECTOR_MIGRATION.md` - Complete migration guide
- `docs/BACKEND_DATABASE_REQUIREMENTS.md` - Database requirements
