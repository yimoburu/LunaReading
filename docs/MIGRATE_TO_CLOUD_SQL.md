# Migrate to Cloud SQL MySQL

This guide will help you migrate from SQLite to Cloud SQL MySQL for persistent database storage.

## Why Migrate?

- ✅ **Persistent Storage**: Data survives container restarts
- ✅ **Better Performance**: Optimized for production workloads
- ✅ **Backups**: Automatic backups and point-in-time recovery
- ✅ **Scalability**: Can handle larger datasets
- ✅ **Production Ready**: Suitable for production deployments

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **gcloud CLI** installed and authenticated
3. **Cloud Run service** already deployed

## Step 1: Create Cloud SQL MySQL Instance

Run the setup script:

```bash
./scripts/setup_cloud_sql.sh [PROJECT_ID] [REGION] [INSTANCE_NAME] [DATABASE_NAME] [DB_USER] [TIER]
```

**Example:**
```bash
./scripts/setup_cloud_sql.sh lunareading-app us-central1 lunareading-db lunareading lunareading_user db-f1-micro
```

**Or with defaults (uses gcloud project):**
```bash
gcloud config set project lunareading-app
./scripts/setup_cloud_sql.sh
```

This will:
- Create a Cloud SQL MySQL 8.0 instance
- Create the database
- Create a database user
- Set up permissions
- Save passwords to `.cloudsql_password` and `.cloudsql_user_password`

**⚠️ Important**: The password files are created in the project root. They are already in `.gitignore` but keep them secure!

## Step 2: Update Cloud Run Service

Update the Cloud Run service to use Cloud SQL:

```bash
./scripts/update_cloud_run_db.sh us-central1
```

This will:
- Add Cloud SQL instance to the service
- Update environment variables with MySQL connection string
- Configure the service account permissions

## Step 3: Install MySQL Dependencies

Install required Python packages:

```bash
pip install pymysql sqlalchemy
```

Or install all requirements:

```bash
pip install -r requirements.txt
```

## Step 4: Migrate Data from SQLite to MySQL

**Option A: Migrate existing data (if you have data in SQLite)**

```bash
# Set the connection string (from Step 2 output)
export SQLALCHEMY_DATABASE_URI="mysql+pymysql://user:password@/lunareading?unix_socket=/cloudsql/PROJECT:REGION:INSTANCE"

# Run migration
python3 scripts/migrate_to_mysql.py
```

**Option B: Start fresh (if no important data)**

The database tables will be created automatically when the app starts.

## Step 5: Verify Migration

### Check MySQL connection:

```bash
# Using the query tool (update connection string first)
python3 scripts/query_db.py
```

### Test the application:

1. Access your Cloud Run frontend URL
2. Try registering a new user
3. Create a reading session
4. Verify data persists

## Step 6: Update Local Development (Optional)

For local development with Cloud SQL, you can use Cloud SQL Proxy:

```bash
# Install Cloud SQL Proxy
# https://cloud.google.com/sql/docs/mysql/sql-proxy

# Start proxy
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306

# Update .env file
SQLALCHEMY_DATABASE_URI=mysql+pymysql://user:password@127.0.0.1:3306/lunareading
```

## Cost Information

**Cloud SQL db-f1-micro tier:**
- **Cost**: ~$7-25/month (depending on region)
- **Specs**: 
  - Shared CPU
  - 0.6 GB RAM
  - 10 GB storage (auto-increase)
  - Suitable for small to medium applications

**Free Tier**: Google Cloud provides $300 free credit for new accounts (90 days)

## Troubleshooting

### "Permission denied" when connecting

**Solution**: Ensure Cloud Run service account has Cloud SQL Client role:
```bash
PROJECT_NUMBER=$(gcloud projects describe PROJECT_ID --format='value(projectNumber)')
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/cloudsql.client"
```

### "Instance connection failed"

**Solution**: 
1. Verify instance name is correct
2. Check that Cloud SQL instance is in the same region (or use private IP)
3. Ensure Cloud Run service has the instance added:
   ```bash
   gcloud run services describe lunareading-backend --region REGION
   ```

### Migration fails

**Solution**:
1. Check MySQL connection string is correct
2. Verify database and user exist
3. Check that tables don't already have data (migration will truncate)
4. Review error messages for specific issues

### Connection string format

The connection string should be:
```
mysql+pymysql://USER:PASSWORD@/DATABASE?unix_socket=/cloudsql/CONNECTION_NAME
```

Where `CONNECTION_NAME` is: `PROJECT_ID:REGION:INSTANCE_NAME`

## Rollback (if needed)

If you need to rollback to SQLite:

```bash
# Update Cloud Run service
gcloud run services update lunareading-backend \
    --region us-central1 \
    --update-env-vars "SQLALCHEMY_DATABASE_URI=sqlite:////tmp/lunareading.db" \
    --remove-cloudsql-instances PROJECT:REGION:INSTANCE
```

## Next Steps

1. ✅ Set up automated backups (already enabled by default)
2. ✅ Monitor database performance in Cloud Console
3. ✅ Set up alerts for database issues
4. ✅ Consider upgrading tier if needed
5. ✅ Document connection details securely

## Security Best Practices

1. ✅ Passwords are saved to files (already in .gitignore)
2. ✅ Use Secret Manager for production (recommended)
3. ✅ Enable SSL/TLS for connections
4. ✅ Use private IP if possible
5. ✅ Regularly rotate passwords
6. ✅ Limit database user permissions

## Using Secret Manager (Advanced)

For better security, store credentials in Secret Manager:

```bash
# Create secrets
echo -n "mysql+pymysql://user:pass@/db?unix_socket=/cloudsql/..." | \
    gcloud secrets create database-uri --data-file=-

# Grant access
gcloud secrets add-iam-policy-binding database-uri \
    --member="serviceAccount:SERVICE_ACCOUNT" \
    --role="roles/secretmanager.secretAccessor"

# Update Cloud Run
gcloud run services update lunareading-backend \
    --update-secrets SQLALCHEMY_DATABASE_URI=database-uri:latest
```

## Support

If you encounter issues:
1. Check Cloud SQL instance status in Cloud Console
2. Review Cloud Run logs: `gcloud run services logs read lunareading-backend`
3. Verify connection string format
4. Check IAM permissions

