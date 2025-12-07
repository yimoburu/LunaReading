# Query Cloud Database Usage Guide

## Overview

This tool allows you to query the database deployed on Google Cloud Run. It supports both:
- **SQLite** (ephemeral, stored in `/tmp/lunareading.db` in the container)
- **Cloud SQL** (persistent PostgreSQL/MySQL database)

## Prerequisites

1. **gcloud CLI installed**: https://cloud.google.com/sdk/docs/install
2. **Authenticated**: `gcloud auth login`
3. **Project set**: `gcloud config set project YOUR_PROJECT_ID`

## Current Setup

The current deployment uses **SQLite** stored in `/tmp/lunareading.db` inside the Cloud Run container. This is **ephemeral** - data is lost when the container restarts.

## Usage

### Interactive Mode

```bash
python3 scripts/query_cloud_db.py lunareading-backend us-central1
```

This will:
1. Detect the database type (SQLite or Cloud SQL)
2. Enter interactive mode where you can:
   - List tables: `tables`
   - Show schema: `schema user`
   - Execute queries: `sql SELECT * FROM user LIMIT 5`
   - Exit: `exit`

### Single Query Mode

```bash
# List all users
python3 scripts/query_cloud_db.py lunareading-backend us-central1 "SELECT * FROM user"

# Count users
python3 scripts/query_cloud_db.py lunareading-backend us-central1 "SELECT COUNT(*) as total FROM user"

# List sessions
python3 scripts/query_cloud_db.py lunareading-backend us-central1 "SELECT * FROM reading_session LIMIT 10"
```

## Methods for Querying Cloud Database

### Method 1: Using query_cloud_db.py (SQLite only)

For SQLite databases in Cloud Run containers:

```bash
python3 scripts/query_cloud_db.py lunareading-backend us-central1
```

**Limitations:**
- Only works for SQLite databases
- Requires `gcloud run services exec` permissions
- Data is ephemeral (lost on container restart)

### Method 2: Using gcloud run exec (Direct Container Access)

Execute commands directly in the running container:

```bash
# Connect to container shell
gcloud run services exec lunareading-backend \
  --region us-central1 \
  --command /bin/sh

# Once inside, you can use sqlite3
sqlite3 /tmp/lunareading.db "SELECT * FROM user;"
```

Or execute a single command:

```bash
gcloud run services exec lunareading-backend \
  --region us-central1 \
  --command "sqlite3 /tmp/lunareading.db 'SELECT * FROM user LIMIT 5;'"
```

### Method 3: Download Database File (SQLite)

Download the database file from the container:

```bash
# Create a script in the container to copy DB to Cloud Storage
# Or use gcloud run services exec to export data

# Export to JSON
gcloud run services exec lunareading-backend \
  --region us-central1 \
  --command "python3 -c \"
import sqlite3, json
conn = sqlite3.connect('/tmp/lunareading.db')
conn.row_factory = sqlite3.Row
cursor = conn.cursor()
cursor.execute('SELECT * FROM user')
rows = [dict(row) for row in cursor.fetchall()]
print(json.dumps(rows, indent=2))
\""
```

### Method 4: Cloud SQL (If Using Cloud SQL)

If you've migrated to Cloud SQL:

#### Option A: Using gcloud sql connect

```bash
# Connect to Cloud SQL instance
gcloud sql connect INSTANCE_NAME --user=root --database=lunareading

# Then run SQL queries
SELECT * FROM user;
```

#### Option B: Using Cloud SQL Proxy

```bash
# Install Cloud SQL Proxy
# https://cloud.google.com/sql/docs/mysql/sql-proxy

# Start proxy
cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306

# Connect with local client
mysql -u root -p -h 127.0.0.1 -D lunareading
# or
psql -h 127.0.0.1 -U root -d lunareading
```

#### Option C: Using local query_db.py with Cloud SQL

Update the connection string in `query_db.py` to use Cloud SQL connection string.

## Common Queries

### List all users
```sql
SELECT id, username, email, grade_level, reading_level, created_at 
FROM user 
ORDER BY created_at DESC;
```

### User statistics
```sql
SELECT 
    u.username,
    COUNT(DISTINCT s.id) as sessions,
    COUNT(DISTINCT q.id) as questions,
    AVG(a.score) as avg_score
FROM user u
LEFT JOIN reading_session s ON u.id = s.user_id
LEFT JOIN question q ON s.id = q.session_id
LEFT JOIN answer a ON q.id = a.question_id AND a.is_final = 1
GROUP BY u.id;
```

### Recent sessions
```sql
SELECT 
    s.id,
    u.username,
    s.book_title,
    s.chapter,
    s.created_at,
    s.completed_at
FROM reading_session s
JOIN user u ON s.user_id = u.id
ORDER BY s.created_at DESC
LIMIT 20;
```

## Important Notes

### SQLite on Cloud Run (Current Setup)

⚠️ **Data is Ephemeral**
- Database is stored in `/tmp/lunareading.db` inside the container
- Data is **lost** when:
  - Container restarts
  - Service is updated/redeployed
  - Container is scaled to zero

**For Production**: Migrate to Cloud SQL for persistent storage.

### Cloud SQL (Recommended for Production)

✅ **Persistent Storage**
- Data persists across deployments
- Better performance
- Supports backups
- Cost: ~$7-25/month for db-f1-micro

**Setup Cloud SQL:**
```bash
# Create instance
gcloud sql instances create lunareading-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database
gcloud sql databases create lunareading --instance=lunareading-db

# Update Cloud Run service
gcloud run services update lunareading-backend \
  --add-cloudsql-instances=PROJECT:REGION:lunareading-db \
  --update-env-vars CLOUDSQL_INSTANCE_CONNECTION_NAME=PROJECT:REGION:lunareading-db,CLOUDSQL_USER=user,CLOUDSQL_PASSWORD=pass,CLOUDSQL_DATABASE=lunareading
```

## Troubleshooting

### "gcloud run services exec" fails

**Error**: Permission denied or service not found

**Solutions**:
1. Check service name: `gcloud run services list`
2. Check region: `gcloud run services describe SERVICE_NAME --region REGION`
3. Ensure you have Cloud Run Admin permissions

### Database file not found

**Error**: Database file doesn't exist in container

**Solutions**:
1. Check if database has been initialized (first request creates it)
2. Verify database path in environment variables
3. Check container logs: `gcloud run services logs read SERVICE_NAME --limit 50`

### Query returns empty results

**Possible reasons**:
1. Database is empty (no data yet)
2. Container was restarted (SQLite data lost)
3. Wrong database path

## Security Notes

- ⚠️ Queries execute with container permissions
- ⚠️ Be careful with UPDATE/DELETE queries
- ⚠️ SQLite on Cloud Run is not suitable for production
- ✅ Use Cloud SQL for production with proper access controls

