# Backend Database Requirements

## Overview

The LunaReading backend **ONLY** supports **Cloud SQL MySQL** using Google Cloud SQL Connector. SQLite and other databases are **NOT** supported.

## Requirements

### Required Configuration

The following environment variables **MUST** be set:

- `CLOUDSQL_INSTANCE_CONNECTION_NAME` - Format: `project:region:instance`
- `CLOUDSQL_USER` - Database username
- `CLOUDSQL_PASSWORD` - Database password
- `CLOUDSQL_DATABASE` - Database name (defaults to 'lunareading')

**Example:**
```bash
CLOUDSQL_INSTANCE_CONNECTION_NAME=lunareading-app:us-central1:free-trial-first-project
CLOUDSQL_USER=lunareading_user
CLOUDSQL_PASSWORD=password123
CLOUDSQL_DATABASE=lunareading
```

### What Happens If Not Set

If required environment variables are not set:
- ❌ Application will **fail to start** with a clear error message
- ❌ No fallback to SQLite
- ❌ No default database

## Setup

### Quick Setup

```bash
# 1. Set up Cloud SQL (if not already done)
./scripts/setup_cloud_sql.sh

# 2. Configure connection (update scripts to use new env vars)
# See docs/CLOUDSQL_CONNECTOR_MIGRATION.md for details
```

### Manual Setup

1. Add to `.env` file:
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME="project:region:instance"
   CLOUDSQL_USER="your-username"
   CLOUDSQL_PASSWORD="your-password"
   CLOUDSQL_DATABASE="lunareading"
   ```

2. Get connection info:
   - Connection Name: `gcloud sql instances describe INSTANCE_NAME --format='value(connectionName)'`
   - User/Password: From `.cloudsql_user_password` file or create new user
   - Database: Usually `lunareading`

## Error Diagnostics

The backend includes automatic error diagnostics. When a database connection fails, you'll see:

```
🔍 Cloud SQL Connection Diagnostics:

❌ Cannot connect to database server

Possible causes:
  1. Cloud SQL instance is not running
  2. Instance connection name is incorrect
  3. Cloud SQL instance not added to Cloud Run service
...
```

### Common Errors and Solutions

#### "Cannot connect to database server"

**Causes:**
- Cloud SQL instance is stopped
- Instance connection name incorrect
- Instance not added to Cloud Run service

**Solutions:**
```bash
# Check instance status
gcloud sql instances list

# Start instance if stopped
gcloud sql instances patch INSTANCE_NAME --activation-policy=ALWAYS

# Add to Cloud Run service
./scripts/update_cloud_run_db.sh
```

#### "Access denied" or "Authentication failed"

**Causes:**
- Wrong username or password
- User doesn't exist

**Solutions:**
```bash
# Check credentials in .cloudsql_user_password
cat .cloudsql_user_password

# Reset password
gcloud sql users set-password USERNAME \
  --instance=INSTANCE_NAME \
  --password=NEW_PASSWORD
```

#### "Unknown database"

**Causes:**
- Database doesn't exist

**Solutions:**
```bash
# Create database
gcloud sql databases create lunareading --instance=INSTANCE_NAME
```

#### "Permission denied"

**Causes:**
- Service account missing Cloud SQL Client role
- Instance not added to Cloud Run service

**Solutions:**
```bash
# Grant Cloud SQL Client role
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client"

# Add instance to Cloud Run
./scripts/update_cloud_run_db.sh
```

## Local Development

### Option 1: Use Cloud SQL Proxy (Recommended)

1. Install Cloud SQL Proxy: https://cloud.google.com/sql/docs/mysql/sql-proxy

2. Start proxy:
   ```bash
   cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306
   ```

3. Update `.env` to use TCP connection:
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME="project:region:instance"
   CLOUDSQL_USER="user"
   CLOUDSQL_PASSWORD="password"
   CLOUDSQL_DATABASE="lunareading"
   ```

### Option 2: Deploy to Cloud Run

Deploy to Cloud Run where Cloud SQL Connector works automatically:
```bash
# Deploy backend
gcloud run deploy lunareading-backend \
  --source . \
  --region us-central1
```

## Validation

The backend validates the configuration on startup:

✅ **Valid:**
- All required environment variables set
- Valid instance connection name format
- Valid credentials

❌ **Invalid:**
- Missing required environment variables
- Invalid connection name format
- Invalid credentials

## Code Changes

All SQLite support has been removed:
- ❌ No SQLite fallback
- ❌ No default SQLite database
- ❌ No SQLite path handling
- ✅ Only Cloud SQL MySQL supported via Cloud SQL Connector
- ✅ Clear error messages
- ✅ Automatic diagnostics

## Troubleshooting

If you see connection errors:

1. **Check environment variables:**
   ```bash
   grep CLOUDSQL .env
   ```

2. **Test connection:**
   ```bash
   python3 scripts/query_cloud_db.py
   ```

3. **View diagnostics:**
   - Check application logs
   - Error messages include diagnostic information

4. **Verify Cloud SQL:**
   ```bash
   gcloud sql instances list
   gcloud sql instances describe INSTANCE_NAME
   ```

## Summary

- ✅ **Only Cloud SQL MySQL** is supported via Cloud SQL Connector
- ❌ **SQLite is NOT supported**
- ✅ **Clear error messages** with diagnostics
- ✅ **Automatic root cause analysis**

For help, see:
- `docs/CLOUDSQL_CONNECTOR_MIGRATION.md` - Migration and setup guide
- `docs/DATABASE_CONNECTION.md` - Connection setup guide
