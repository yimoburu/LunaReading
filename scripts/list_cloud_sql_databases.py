#!/usr/bin/env python3
"""
List all databases in a Cloud SQL instance
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
USER = os.getenv('CLOUDSQL_USER')
PASSWORD = os.getenv('CLOUDSQL_PASSWORD')

if not INSTANCE_CONNECTION_NAME:
    print("❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set in .env")
    sys.exit(1)

if not USER or not PASSWORD:
    print("❌ ERROR: CLOUDSQL_USER and CLOUDSQL_PASSWORD must be set in .env")
    sys.exit(1)

print(f"Connecting to Cloud SQL instance: {INSTANCE_CONNECTION_NAME}")
print(f"User: {USER}")
print()

try:
    # Initialize connector
    connector = Connector()
    
    # Connect to MySQL (without specifying a database)
    def get_conn():
        return connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=USER,
            password=PASSWORD,
        )
    
    # List all databases
    with get_conn() as conn:
        with conn.cursor() as cursor:
            cursor.execute("SHOW DATABASES")
            databases = cursor.fetchall()
            
            print("📊 Available databases:")
            print("-" * 50)
            for (db_name,) in databases:
                # Skip system databases
                if db_name.lower() not in ['information_schema', 'performance_schema', 'mysql', 'sys']:
                    print(f"  ✓ {db_name}")
                else:
                    print(f"    {db_name} (system)")
            
            print("-" * 50)
            print(f"\nTotal: {len(databases)} databases")
            
            # Check if 'lunareading' exists
            db_names = [db[0] for db in databases]
            if 'lunareading' in db_names:
                print("\n✅ Database 'lunareading' exists")
                print("   Set CLOUDSQL_DATABASE=lunareading in your .env file")
            else:
                print("\n⚠️  Database 'lunareading' does not exist")
                print("   You can create it with:")
                print(f"   gcloud sql databases create lunareading --instance={INSTANCE_CONNECTION_NAME.split(':')[-1]}")
                
                # Suggest using an existing database
                user_databases = [db for db in db_names if db.lower() not in ['information_schema', 'performance_schema', 'mysql', 'sys']]
                if user_databases:
                    print(f"\n   Or use an existing database:")
                    for db in user_databases:
                        print(f"   CLOUDSQL_DATABASE={db}")
    
    connector.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
    print(f"   Error type: {type(e).__name__}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

