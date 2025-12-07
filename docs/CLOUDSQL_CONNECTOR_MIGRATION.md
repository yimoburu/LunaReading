# Cloud SQL Connector Migration Guide

This document describes the migration to Google Cloud SQL Connector for database operations.

## Overview

The LunaReading backend uses Google Cloud SQL Connector to connect to Cloud SQL (MySQL) instances. This provides a secure, managed way to connect to Cloud SQL without requiring public IP addresses or managing SSL certificates manually.

## Changes Made

### 1. Dependencies (`requirements.txt`)
- **Removed:**
  - `google-cloud-bigquery==3.25.0`
  - `google-auth==2.35.0`
  
- **Added:**
  - `google-cloud-sql-connector==1.11.0`
  - `pymysql==1.1.0`

### 2. New Cloud SQL Client (`backend/cloudsql_client.py`)
- Created a comprehensive Cloud SQL client wrapper that:
  - Uses Google Cloud SQL Connector for secure connections
  - Handles all CRUD operations for Users, ReadingSessions, Questions, and Answers
  - Uses PyMySQL for MySQL database operations
  - Provides connection pooling through the connector
  - Automatically creates tables on initialization

### 3. Configuration (`backend/config.py`)
- **Removed:**
  - `BIGQUERY_PROJECT_ID`
  - `BIGQUERY_DATASET_ID`
  - `BIGQUERY_CREDENTIALS_PATH`
  
- **Added:**
  - `CLOUDSQL_INSTANCE_CONNECTION_NAME` (required) - Format: `project:region:instance`
  - `CLOUDSQL_DATABASE` (defaults to 'lunareading')
  - `CLOUDSQL_USER` (required) - Database username
  - `CLOUDSQL_PASSWORD` (required) - Database password

### 4. Application Factory (`backend/__init__.py`)
- Removed BigQuery client initialization
- Added Cloud SQL client initialization using the connector
- Cloud SQL client is attached to the Flask app as `app.db_client`

### 5. Route Files
All route files have been updated to use Cloud SQL instead of BigQuery:
- `backend/routes/auth.py` - User registration and login
- `backend/routes/profile.py` - User profile management
- `backend/routes/sessions.py` - Reading session management
- `backend/routes/questions.py` - Question and answer handling
- `backend/routes/admin.py` - Admin statistics

## Environment Variables

Add these to your `.env` file:

```bash
# Required
CLOUDSQL_INSTANCE_CONNECTION_NAME=your-project:your-region:your-instance
CLOUDSQL_USER=your-database-user
CLOUDSQL_PASSWORD=your-database-password

# Optional (defaults to 'lunareading')
CLOUDSQL_DATABASE=lunareading
```

## Setup Instructions

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set up GCP credentials:**
   - The Cloud SQL Connector uses Application Default Credentials (ADC)
   - Run: `gcloud auth application-default login`
   - Or set `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to a service account JSON file

3. **Enable Cloud SQL Admin API:**
   ```bash
   gcloud services enable sqladmin.googleapis.com
   ```

4. **Grant necessary permissions:**
   ```bash
   # For service account (if using service account)
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member='serviceAccount:SERVICE_ACCOUNT' \
     --role='roles/cloudsql.client'
   ```

5. **Create Cloud SQL instance (if not exists):**
   ```bash
   gcloud sql instances create INSTANCE_NAME \
     --database-version=MYSQL_8_0 \
     --tier=db-f1-micro \
     --region=REGION
   ```

6. **Create database (if not exists):**
   ```bash
   gcloud sql databases create DATABASE_NAME --instance=INSTANCE_NAME
   ```

7. **Create database user (if not exists):**
   ```bash
   gcloud sql users create USERNAME --instance=INSTANCE_NAME --password=PASSWORD
   ```

8. **Run the application:**
   - Tables will be created automatically on first run
   - The application will initialize Cloud SQL connection on startup

## Benefits of Cloud SQL Connector

1. **Security:** No need to expose Cloud SQL instance with public IP
2. **Simplicity:** Automatic SSL/TLS certificate management
3. **Reliability:** Built-in connection pooling and retry logic
4. **Compatibility:** Works with standard MySQL drivers (PyMySQL)
5. **Flexibility:** Works both locally and on Cloud Run/GCE

## Important Notes

### Connection Management
- The Cloud SQL Connector manages connections automatically
- Connections are pooled for better performance
- The connector handles authentication and SSL/TLS automatically

### Database Operations
- All operations use standard SQL queries (not ORM)
- Transactions are supported (MySQL ACID compliance)
- Foreign key constraints are enforced
- Auto-increment IDs are used for primary keys

### Local Development
- Works seamlessly with Cloud SQL Proxy alternative
- No need to manage SSL certificates manually
- Uses Application Default Credentials for authentication

## Troubleshooting

### Authentication Errors
- Verify Application Default Credentials are set up correctly
- Check that the service account (if used) has `cloudsql.client` role
- Ensure Cloud SQL Admin API is enabled

### Connection Errors
- Verify `CLOUDSQL_INSTANCE_CONNECTION_NAME` format: `project:region:instance`
- Check that the Cloud SQL instance is running
- Verify database user and password are correct
- Ensure the database exists

### Permission Errors
- Grant `roles/cloudsql.client` to the service account
- Verify the service account has access to the Cloud SQL instance
- Check IAM bindings: `gcloud projects get-iam-policy PROJECT_ID`

### Database Errors
- Tables are created automatically, but verify table creation succeeded
- Check database logs: `gcloud sql operations list --instance=INSTANCE_NAME`
- Verify foreign key constraints are working correctly

## Testing

After migration, test the following:
1. User registration
2. User login
3. Creating reading sessions
4. Submitting answers
5. Viewing session history
6. Admin statistics

## Performance Considerations

- The Cloud SQL Connector uses connection pooling
- Connections are reused across requests
- Consider connection pool size for high-traffic applications
- Monitor Cloud SQL instance metrics for performance

## Security Best Practices

1. **Never commit credentials:** Keep `.env` file out of version control
2. **Use service accounts:** Prefer service accounts over user credentials in production
3. **Rotate passwords:** Regularly update database passwords
4. **Limit access:** Grant minimum necessary permissions
5. **Enable audit logs:** Monitor database access

## Rollback

If you need to rollback:
1. Restore `requirements.txt` from git history
2. Restore `backend/config.py` from git history
3. Restore `backend/__init__.py` from git history
4. Restore all route files from git history
5. Reinstall previous dependencies

