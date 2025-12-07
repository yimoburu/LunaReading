# Local Development Setup

This guide explains how to set up the backend for local development.

## Quick Start

### 1. Install Dependencies

```bash
# Activate virtual environment
source .venv/bin/activate  # or: python -m venv .venv

# Install all dependencies
pip install -r requirements.txt
```

### 2. Set Up Database

**For local development, use Cloud SQL via Cloud SQL Proxy (recommended):**

1. **Set up Application Default Credentials:**
   ```bash
   gcloud auth application-default login
   ```

2. **Install Cloud SQL Proxy:**
   - Download from: https://cloud.google.com/sql/docs/mysql/sql-proxy
   - Or: `gcloud components install cloud-sql-proxy`

3. **Start Cloud SQL Proxy:**
   ```bash
   cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306
   ```

4. **Configure environment variables in `.env`:**
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
   CLOUDSQL_USER=your-username
   CLOUDSQL_PASSWORD=your-password
   CLOUDSQL_DATABASE=lunareading
   ```

### 3. Run the Backend

```bash
# Option 1: Using the run script (recommended)
python run_backend.py

# Option 2: As a module
python -m backend.app

# Option 3: Directly
python backend/app.py
```

The server will start on `http://localhost:5001` (or port specified by `PORT` env var).

## Database Options for Local Development

### Option 1: Cloud SQL via Cloud SQL Proxy (Recommended)

**Pros:**
- Same database as production
- Tests real MySQL behavior
- Uses Cloud SQL Connector (same as production)

**Cons:**
- Requires Cloud SQL Proxy setup
- Needs internet connection
- Requires Cloud SQL instance

**Setup:**
1. Install Cloud SQL Proxy: https://cloud.google.com/sql/docs/mysql/sql-proxy
2. Start proxy:
   ```bash
   cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306
   ```
3. Set environment variables in `.env`:
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
   CLOUDSQL_USER=your-username
   CLOUDSQL_PASSWORD=your-password
   CLOUDSQL_DATABASE=lunareading
   ```

### Option 2: Cloud SQL Direct (Without Proxy)

**Pros:**
- No proxy needed
- Simpler setup

**Cons:**
- Requires proper IAM permissions
- May have network restrictions

**Setup:**
1. Set up Application Default Credentials:
   ```bash
   gcloud auth application-default login
   ```

2. Set environment variables in `.env`:
   ```bash
   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
   CLOUDSQL_USER=your-username
   CLOUDSQL_PASSWORD=your-password
   CLOUDSQL_DATABASE=lunareading
   ```

### Option 3: Local MySQL

**Pros:**
- Tests MySQL behavior
- No Cloud dependencies
- Works offline

**Cons:**
- Requires local MySQL installation
- Different from production setup
- Need to configure Cloud SQL Connector to work with local MySQL (not recommended)

**Note:** This option is not recommended as it requires significant configuration changes.

## Environment Variables

Create a `.env` file in the project root with:

```bash
# OpenAI API Key (required)
OPENAI_API_KEY=your-openai-api-key-here

# Cloud SQL Connection (required)
CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
CLOUDSQL_USER=your-username
CLOUDSQL_PASSWORD=your-password
CLOUDSQL_DATABASE=lunareading

# JWT Secret (optional, has default)
JWT_SECRET_KEY=your-secret-key-change-in-production

# Flask Debug (optional)
FLASK_DEBUG=True
```

## Common Issues

### "CLOUDSQL_INSTANCE_CONNECTION_NAME is required"

**Solution:** Set the required environment variables in `.env`:
```bash
CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
CLOUDSQL_USER=your-username
CLOUDSQL_PASSWORD=your-password
CLOUDSQL_DATABASE=lunareading
```

### "ModuleNotFoundError: No module named 'pymysql'"

**Solution:**
```bash
pip install pymysql
# Or install all dependencies:
pip install -r requirements.txt
```

### "ModuleNotFoundError: No module named 'google.cloud.sql.connector'"

**Solution:**
```bash
pip install google-cloud-sql-connector[pymysql]
# Or install all dependencies:
pip install -r requirements.txt
```

### "Authentication failed" or "Permission denied"

**Problem:** Application Default Credentials not set up.

**Solution:**
```bash
# Set up Application Default Credentials
gcloud auth application-default login

# Or set service account credentials
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

### "Cannot connect to database server"

**Problem:** Cloud SQL Proxy not running or instance not accessible.

**Solution:**
1. **If using Cloud SQL Proxy:**
   - Make sure proxy is running: `cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306`
   - Check proxy logs for errors

2. **If using direct connection:**
   - Verify instance is running: `gcloud sql instances list`
   - Check IAM permissions: Service account needs `roles/cloudsql.client`
   - Verify network connectivity

### "Unknown database"

**Solution:** Create the database:
```bash
gcloud sql databases create lunareading --instance=INSTANCE_NAME
```

## Setting Up Cloud SQL for Local Development

### 1. Create Cloud SQL Instance (if not exists)

```bash
gcloud sql instances create INSTANCE_NAME \
  --database-version=MYSQL_8_0 \
  --tier=db-f1-micro \
  --region=REGION
```

### 2. Create Database

```bash
gcloud sql databases create lunareading --instance=INSTANCE_NAME
```

### 3. Create Database User

```bash
gcloud sql users create USERNAME --instance=INSTANCE_NAME --password=PASSWORD
```

### 4. Get Connection Name

```bash
gcloud sql instances describe INSTANCE_NAME --format='value(connectionName)'
```

### 5. Configure Environment Variables

Add to `.env`:
```bash
CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance
CLOUDSQL_USER=USERNAME
CLOUDSQL_PASSWORD=PASSWORD
CLOUDSQL_DATABASE=lunareading
```

## Testing the Setup

1. **Start the backend:**
   ```bash
   python run_backend.py
   ```

2. **Check health endpoint:**
   ```bash
   curl http://localhost:5001/
   ```

3. **Test registration:**
   ```bash
   curl -X POST http://localhost:5001/api/register \
     -H "Content-Type: application/json" \
     -d '{"username":"test","email":"test@example.com","password":"test123","grade_level":3}'
   ```

## Development Workflow

1. **Set up Cloud SQL Proxy** for local development
2. **Configure environment variables** in `.env`
3. **Run backend locally** and test
4. **Deploy to Cloud Run** with same Cloud SQL connection

## File Structure

```
LunaReading/
├── .env                    # Environment variables (not in git)
├── backend/
│   ├── app.py
│   ├── config.py
│   ├── cloudsql_client.py  # Cloud SQL client wrapper
│   └── ...
├── scripts/
│   ├── setup_db_connection.sh  # Set up Cloud SQL connection
│   ├── get_db_connection.sh     # View connection info
│   └── ...
└── requirements.txt
```

## Next Steps

- See `docs/DATABASE_CONNECTION.md` for detailed database setup
- See `docs/CLOUDSQL_CONNECTOR_MIGRATION.md` for migration details
- See `backend/README.md` for backend structure
- See `README.md` for overall project documentation
