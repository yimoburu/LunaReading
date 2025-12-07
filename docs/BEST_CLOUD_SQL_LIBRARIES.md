# Best Python Libraries for Google Cloud SQL

## Overview

For connecting to Google Cloud SQL databases in Python, there are several options. This document describes the approach used in LunaReading.

## Current Approach: Google Cloud SQL Python Connector (Direct)

**Library:** `google-cloud-sql-connector[pymysql]`

**Why it's the best:**
- ✅ **Official Google library** - Built and maintained by Google
- ✅ **Automatic IAM authentication** - Uses Application Default Credentials
- ✅ **Automatic SSL/TLS management** - Handles certificates automatically
- ✅ **Connection pooling** - Built-in connection management
- ✅ **Works everywhere** - Cloud Run, local, GCE, etc.
- ✅ **Secure by default** - TLS 1.3 encryption
- ✅ **No manual certificate management**
- ✅ **Direct database access** - No ORM overhead

**Installation:**
```bash
pip install google-cloud-sql-connector[pymysql] pymysql
```

**Usage Example (as used in LunaReading):**
```python
from google.cloud.sql.connector import Connector
import pymysql

# Initialize connector
connector = Connector()

def getconn():
    conn = connector.connect(
        "PROJECT:REGION:INSTANCE",  # Cloud SQL instance connection name
        "pymysql",
        user="DB_USER",
        password="DB_PASSWORD",
        db="DB_NAME",
    )
    return conn

# Use directly with PyMySQL
conn = getconn()
cursor = conn.cursor()
cursor.execute("SELECT 1")
result = cursor.fetchone()
conn.close()
```

**With Connection Context Manager:**
```python
from contextlib import contextmanager

@contextmanager
def get_connection():
    conn = connector.connect(
        "PROJECT:REGION:INSTANCE",
        "pymysql",
        user="DB_USER",
        password="DB_PASSWORD",
        db="DB_NAME",
    )
    try:
        yield conn
    finally:
        conn.close()

# Usage
with get_connection() as conn:
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    user = cursor.fetchone()
```

## Why Not SQLAlchemy?

LunaReading uses Cloud SQL Connector directly with PyMySQL instead of SQLAlchemy because:

- ✅ **Simpler codebase** - No ORM abstraction layer
- ✅ **Better performance** - Direct SQL execution
- ✅ **Full SQL control** - No ORM limitations
- ✅ **Easier to understand** - Standard SQL queries
- ✅ **Fewer dependencies** - One less library to maintain
- ✅ **Better for this use case** - Simple CRUD operations don't need ORM

## Migration Notes

If you're migrating from SQLAlchemy:
1. Replace ORM queries with direct SQL
2. Use PyMySQL cursors for result handling
3. Implement connection management with context managers
4. Update all database operations to use direct SQL

## Security Best Practices

1. **Never commit credentials:**
   - Keep `.env` file out of version control
   - Use Cloud Run secrets for production

2. **Use Application Default Credentials:**
   ```bash
   gcloud auth application-default login
   ```

3. **Grant minimum permissions:**
   - Service account needs `roles/cloudsql.client` role
   - Database user should have minimum required privileges

4. **Enable SSL/TLS:**
   - Cloud SQL Connector handles this automatically
   - Always use in production

## Troubleshooting

### Connection Issues
- Verify `CLOUDSQL_INSTANCE_CONNECTION_NAME` format: `project:region:instance`
- Check Application Default Credentials are set
- Verify service account has `cloudsql.client` role

### Authentication Issues
- Run `gcloud auth application-default login`
- Or set `GOOGLE_APPLICATION_CREDENTIALS` environment variable

### Performance Issues
- Connection pooling is handled automatically by the connector
- Monitor Cloud SQL instance metrics
- Consider connection pool size tuning

## Resources

- [Cloud SQL Python Connector Documentation](https://cloud.google.com/sql/docs/mysql/connect-connectors-python)
- [PyMySQL Documentation](https://pymysql.readthedocs.io/)
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/mysql/best-practices)
