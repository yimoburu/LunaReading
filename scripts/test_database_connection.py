#!/usr/bin/env python3
"""
Test database connection with detailed error diagnostics
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from google.cloud.sql.connector import Connector
import pymysql

# Load .env
project_root = Path(__file__).parent.parent
env_path = project_root / '.env'
load_dotenv(dotenv_path=env_path, override=True)

# Get configuration
INSTANCE_CONNECTION_NAME = os.getenv('CLOUDSQL_INSTANCE_CONNECTION_NAME')
DATABASE = os.getenv('CLOUDSQL_DATABASE', 'lunareading')
USER = os.getenv('CLOUDSQL_USER')
PASSWORD = os.getenv('CLOUDSQL_PASSWORD')

print("🔍 Testing Cloud SQL Connection")
print("=" * 50)
print(f"Instance: {INSTANCE_CONNECTION_NAME}")
print(f"Database: {DATABASE}")
print(f"User: {USER}")
print(f"Password: {'*' * len(PASSWORD) if PASSWORD else 'NOT SET'}")
print()

if not INSTANCE_CONNECTION_NAME:
    print("❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set")
    sys.exit(1)

if not USER:
    print("❌ ERROR: CLOUDSQL_USER not set")
    sys.exit(1)

if not PASSWORD:
    print("❌ ERROR: CLOUDSQL_PASSWORD not set")
    sys.exit(1)

try:
    print("Step 1: Initializing connector...")
    connector = Connector()
    print("✅ Connector initialized")
    print()
    
    print("Step 2: Attempting connection (without database)...")
    try:
        # Try connecting without specifying database first
        conn = connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=USER,
            password=PASSWORD,
        )
        print("✅ Connection successful!")
        
        # Check current database
        with conn.cursor() as cursor:
            cursor.execute("SELECT DATABASE()")
            current_db = cursor.fetchone()[0]
            print(f"   Current database: {current_db}")
        
        conn.close()
        print()
    except Exception as e:
        error_str = str(e).lower()
        error_code = None
        if hasattr(e, 'args') and len(e.args) > 0:
            if isinstance(e.args[0], tuple) and len(e.args[0]) > 0:
                error_code = e.args[0][0]
        
        print(f"❌ Connection failed: {e}")
        print()
        
        if error_code == 1045:
            print("🔍 Error Code 1045: Access Denied")
            print()
            print("Possible causes:")
            print("  1. Wrong password")
            print("  2. User does not exist")
            print("  3. User exists but host restrictions prevent connection")
            print()
            print("Solutions:")
            print("  1. Reset password:")
            instance_name = INSTANCE_CONNECTION_NAME.split(':')[-1]
            print(f"     gcloud sql users set-password {USER} --instance={instance_name} --password=NEW_PASSWORD")
            print()
            print("  2. Create new user:")
            print(f"     gcloud sql users create {USER} --instance={instance_name} --password=NEW_PASSWORD")
            print()
            print("  3. Check existing users:")
            print(f"     gcloud sql users list --instance={instance_name}")
            print()
            print("  4. Update .env with correct password")
        elif 'access denied' in error_str:
            print("🔍 Access Denied Error")
            print()
            print("The user credentials are incorrect or the user doesn't have permission.")
            print("Run: ./scripts/reset_database_user.sh to fix this")
        else:
            print(f"🔍 Unexpected error: {type(e).__name__}")
            print("   Check the error message above for details")
        
        connector.close()
        sys.exit(1)
    
    print("Step 3: Testing connection to specific database...")
    try:
        conn = connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=USER,
            password=PASSWORD,
            db=DATABASE,
        )
        print(f"✅ Connected to database '{DATABASE}'")
        
        # List tables
        with conn.cursor() as cursor:
            cursor.execute("SHOW TABLES")
            tables = cursor.fetchall()
            if tables:
                print(f"   Found {len(tables)} tables: {', '.join([t[0] for t in tables])}")
            else:
                print("   No tables found (database is empty)")
        
        conn.close()
        print()
        print("✅ All connection tests passed!")
        
    except Exception as e:
        error_str = str(e).lower()
        if 'unknown database' in error_str or '1049' in str(e):
            print(f"❌ Database '{DATABASE}' does not exist")
            print()
            print("Solution: Create the database")
            instance_name = INSTANCE_CONNECTION_NAME.split(':')[-1]
            print(f"  gcloud sql databases create {DATABASE} --instance={instance_name}")
            print()
            print("Or run: ./scripts/initialize_database.sh")
        else:
            print(f"❌ Error connecting to database: {e}")
        
        connector.close()
        sys.exit(1)
    
    connector.close()
    
except Exception as e:
    print(f"❌ Unexpected error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("=" * 50)
print("✅ Connection test complete!")

