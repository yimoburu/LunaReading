#!/bin/bash
# Fix database authentication issues

echo "🔐 Fixing database authentication..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ ERROR: .env file not found"
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$CLOUDSQL_INSTANCE_CONNECTION_NAME" ]; then
    echo "❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set in .env"
    exit 1
fi

if [ -z "$CLOUDSQL_USER" ] || [ -z "$CLOUDSQL_PASSWORD" ]; then
    echo "❌ ERROR: CLOUDSQL_USER and CLOUDSQL_PASSWORD must be set in .env"
    exit 1
fi

# Extract instance name
INSTANCE_NAME=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f3)
PROJECT_ID=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f1)

echo "Current configuration:"
echo "  Instance: $INSTANCE_NAME"
echo "  User: $CLOUDSQL_USER"
echo "  Project: $PROJECT_ID"
echo ""

echo "Step 1: Checking if user exists..."
echo "-----------------------------------"
gcloud sql users list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" 2>&1

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Could not list users. This might be a permissions issue."
    echo "   Make sure you have Cloud SQL Admin permissions."
fi

echo ""
echo "Step 2: Testing authentication..."
echo "-----------------------------------"
echo "Attempting to connect with current credentials..."

python3 -c "
import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from google.cloud.sql.connector import Connector
import pymysql

project_root = Path('.').resolve()
env_path = project_root / '.env'
load_dotenv(dotenv_path=env_path, override=True)

INSTANCE = os.getenv('CLOUDSQL_INSTANCE_CONNECTION_NAME')
USER = os.getenv('CLOUDSQL_USER')
PASSWORD = os.getenv('CLOUDSQL_PASSWORD')
DATABASE = os.getenv('CLOUDSQL_DATABASE', 'lunareading')

print(f'Testing connection to: {INSTANCE}')
print(f'User: {USER}')
print(f'Database: {DATABASE}')

try:
    connector = Connector()
    conn = connector.connect(
        INSTANCE,
        'pymysql',
        user=USER,
        password=PASSWORD,
    )
    print('✅ Connection successful!')
    conn.close()
    connector.close()
    sys.exit(0)
except Exception as e:
    print(f'❌ Connection failed: {e}')
    error_str = str(e).lower()
    if 'access denied' in error_str or '1045' in error_str:
        print('')
        print('🔍 Authentication Error Detected:')
        print('   This usually means:')
        print('   1. Wrong password')
        print('   2. User does not exist')
        print('   3. User exists but with different host restrictions')
        print('')
        print('💡 Solutions:')
        print('   1. Reset password:')
        print(f'      gcloud sql users set-password $CLOUDSQL_USER --instance=$INSTANCE_NAME --password=NEW_PASSWORD')
        print('')
        print('   2. Create new user:')
        print(f'      gcloud sql users create $CLOUDSQL_USER --instance=$INSTANCE_NAME --password=$CLOUDSQL_PASSWORD')
        print('')
        print('   3. Check user host restrictions:')
        print(f'      gcloud sql users list --instance=$INSTANCE_NAME')
    sys.exit(1)
" 2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Authentication successful!"
    echo ""
    echo "If you still have issues, try:"
    echo "  1. Verify CLOUDSQL_USER and CLOUDSQL_PASSWORD in .env"
    echo "  2. Check user permissions in Cloud SQL"
else
    echo ""
    echo "❌ Authentication failed"
    echo ""
    echo "Next steps:"
    echo "  1. Reset the user password:"
    echo "     gcloud sql users set-password $CLOUDSQL_USER --instance=$INSTANCE_NAME --password=YOUR_NEW_PASSWORD"
    echo ""
    echo "  2. Or create a new user:"
    echo "     gcloud sql users create $CLOUDSQL_USER --instance=$INSTANCE_NAME --password=YOUR_PASSWORD"
    echo ""
    echo "  3. Update .env with the correct password"
    exit 1
fi

