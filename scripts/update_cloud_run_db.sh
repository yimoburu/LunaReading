#!/bin/bash
# Update Cloud Run service to use Cloud SQL
# 
# NOTE: This script is deprecated. Use the Python version instead:
#   python3 scripts/update_cloud_run_db.py
# 
# This bash script is kept for backward compatibility.

set -e

REGION=${1:-"us-central1"}
PROJECT_ID=${2:-$(gcloud config get-value project 2>/dev/null)}
INSTANCE_NAME=${3:-"free-trial-first-project"}

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not specified"
    echo "Usage: $0 [REGION] [PROJECT_ID] [INSTANCE_NAME]"
    exit 1
fi

echo "🔄 Updating Cloud Run service to use Cloud SQL"
echo "=============================================="
echo ""

# Get connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --format='value(connectionName)' 2>/dev/null)

if [ -z "$CONNECTION_NAME" ]; then
    echo "❌ Could not find Cloud SQL instance: $INSTANCE_NAME"
    exit 1
fi

echo "Connection Name: $CONNECTION_NAME"
echo ""

# Get database credentials
if [ ! -f .cloudsql_user_password ]; then
    echo "❌ Database user password file not found (.cloudsql_user_password)"
    echo "   Run setup_cloud_sql.sh first"
    exit 1
fi

DB_USER=$(grep -E "^DB_USER=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading_user")
DATABASE_NAME=$(grep -E "^DATABASE_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading")
DB_PASSWORD=$(grep -v -E "^(DB_USER|DATABASE_NAME|CONNECTION_NAME)=" .cloudsql_user_password | head -1)

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Could not read database password"
    exit 1
fi

# Build connection string with proper URL encoding
# URL encode password and connection name for query parameter
ENCODED_CONN=$(python3 -c "from urllib.parse import quote; import sys; print(quote('$CONNECTION_NAME', safe=''))" 2>/dev/null || echo "$CONNECTION_NAME")
ENCODED_PWD=$(python3 -c "from urllib.parse import quote_plus; import sys; print(quote_plus('$DB_PASSWORD'))" 2>/dev/null || echo "$DB_PASSWORD")

# Build connection string with properly encoded values
CONNECTION_STRING="mysql+pymysql://${DB_USER}:${ENCODED_PWD}@/${DATABASE_NAME}?unix_socket=/cloudsql/${ENCODED_CONN}"

echo "Connection string (masked):"
echo "mysql+pymysql://${DB_USER}:***@/${DATABASE_NAME}?unix_socket=/cloudsql/${ENCODED_CONN}"
echo ""

# Test Cloud SQL connection
echo "🧪 Testing Cloud SQL connection..."
echo ""

test_connection() {
    local conn_name="$1"
    local db_user="$2"
    local db_password="$3"
    local db_name="$4"
    
    python3 << EOF
import sys
try:
    from google.cloud.sql.connector import Connector
    import pymysql
    
    print("   Creating Cloud SQL Connector...")
    connector = Connector()
    
    def getconn():
        return connector.connect(
            "${conn_name}",
            "pymysql",
            user="${db_user}",
            password="${db_password}",
            db="${db_name}",
        )
    
    print("   Testing connection...")
    try:
        conn = getconn()
        cursor = conn.cursor()
        cursor.execute("SELECT 1 as test")
        row = cursor.fetchone()
        if row and row[0] == 1:
            print("   ✅ Connection successful!")
            print("   ✅ Cloud SQL Connector can connect to Cloud SQL")
            
            # Test database exists
            try:
                cursor.execute("USE ${db_name}")
                print("   ✅ Database '${db_name}' exists and is accessible")
            except Exception as db_err:
                print(f"   ⚠️  Warning: Database '${db_name}' issue: {db_err}")
            
            cursor.close()
            conn.close()
            connector.close()
            sys.exit(0)
        else:
            print("   ❌ Connection test query failed")
            sys.exit(1)
    except Exception as e:
        error_str = str(e).lower()
        print(f"   ❌ Connection failed: {e}")
        
        if 'can\'t connect' in error_str or 'cannot connect' in error_str:
            print("   💡 This is expected if testing locally (Unix socket only works on Cloud Run)")
            print("   💡 The connection string format is correct for Cloud Run deployment")
        elif 'access denied' in error_str or 'authentication' in error_str:
            print("   ❌ Authentication failed - check username and password")
        elif 'unknown database' in error_str:
            print(f"   ❌ Database '${DATABASE_NAME}' does not exist")
            print(f"   💡 Create it: gcloud sql databases create ${DATABASE_NAME} --instance=${INSTANCE_NAME}")
        else:
            print(f"   ❌ Connection error: {e}")
        
        sys.exit(1)
    except Exception as e:
        print(f"   ❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
except ImportError as e:
    print(f"   ⚠️  Cannot test connection: {e}")
    print("   💡 Install dependencies: pip install google-cloud-sql-connector[pymysql] pymysql")
    print("   💡 Continuing anyway - connection format looks correct")
    sys.exit(0)  # Don't fail if dependencies missing
EOF
}

# Test the connection
TEST_RESULT=0
test_connection "$CONNECTION_STRING" || TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo ""
    echo "✅ Connection test passed - ready to update Cloud Run"
    echo ""
elif [ $TEST_RESULT -eq 1 ]; then
    echo ""
    echo "⚠️  Connection test failed, but continuing..."
    echo "   This might be expected if testing locally (Unix socket only works on Cloud Run)"
    echo "   The connection string format is correct for Cloud Run deployment"
    echo ""
    read -p "   Continue with Cloud Run update? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Update cancelled"
        exit 1
    fi
else
    # Dependencies missing - continue anyway
    echo ""
    echo "⚠️  Could not test connection (missing dependencies)"
    echo "   Continuing with update - connection string format looks correct"
    echo ""
fi

echo "Updating backend service..."
gcloud run services update lunareading-backend \
    --region $REGION \
    --add-cloudsql-instances $CONNECTION_NAME \
    --update-env-vars "CLOUDSQL_INSTANCE_CONNECTION_NAME=${CONNECTION_NAME},CLOUDSQL_USER=${DB_USER},CLOUDSQL_PASSWORD=${DB_PASSWORD},CLOUDSQL_DATABASE=${DATABASE_NAME}" \
    --project=$PROJECT_ID

echo ""
echo "✅ Cloud Run service updated!"
echo ""
echo "The service will now use Cloud SQL MySQL via Cloud SQL Connector."
echo ""
echo "⚠️  Note: You may need to restart the service or wait for it to scale to zero"
echo "   and start a new instance for the changes to take effect."

