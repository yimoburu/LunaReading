#!/usr/bin/env python3
"""
Grant database permissions to user via SQL
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

# Get root/admin credentials (if different)
ROOT_USER = os.getenv('CLOUDSQL_ROOT_USER', 'root')
ROOT_PASSWORD = os.getenv('CLOUDSQL_ROOT_PASSWORD', PASSWORD)

if not INSTANCE_CONNECTION_NAME:
    print("❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set in .env")
    sys.exit(1)

if not USER:
    print("❌ ERROR: CLOUDSQL_USER not set in .env")
    sys.exit(1)

# Check if database is a system database
if DATABASE in ['mysql', 'information_schema', 'performance_schema', 'sys']:
    print(f"❌ ERROR: Cannot grant permissions on system database '{DATABASE}'")
    print("")
    print("Please set CLOUDSQL_DATABASE to a non-system database name in your .env file:")
    print("  CLOUDSQL_DATABASE=lunareading")
    sys.exit(1)

print(f"🔐 Granting permissions to user '{USER}' on database '{DATABASE}'")
print(f"   Instance: {INSTANCE_CONNECTION_NAME}")
print()

try:
    connector = Connector()
    
    # Try to connect as root/admin first
    print("Attempting to connect as root/admin user...")
    try:
        root_conn = connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=ROOT_USER,
            password=ROOT_PASSWORD,
        )
        print("✅ Connected as root/admin")
        
        with root_conn.cursor() as cursor:
            # Grant all privileges
            print(f"Granting ALL PRIVILEGES on `{DATABASE}`.* to '{USER}'@'%'...")
            cursor.execute(f"GRANT ALL PRIVILEGES ON `{DATABASE}`.* TO %s@'%%'", (USER,))
            
            # Flush privileges
            print("Flushing privileges...")
            cursor.execute("FLUSH PRIVILEGES")
            
            root_conn.commit()
            print("✅ Permissions granted successfully!")
        
        root_conn.close()
        connector.close()
        sys.exit(0)
        
    except Exception as root_error:
        error_str = str(root_error).lower()
        if 'access denied' in error_str or '1045' in str(root_error):
            print(f"⚠️  Cannot connect as root/admin: {root_error}")
            print()
            print("You need root/admin access to grant permissions.")
            print("Options:")
            print("  1. Set CLOUDSQL_ROOT_USER and CLOUDSQL_ROOT_PASSWORD in .env")
            print("  2. Or grant permissions manually via Cloud SQL console")
            print("  3. Or use a user with GRANT privileges")
        else:
            raise
    
    # If root connection failed, try with regular user (might have GRANT privilege)
    print()
    print("Attempting to grant permissions with regular user...")
    if not PASSWORD:
        print("❌ ERROR: CLOUDSQL_PASSWORD not set")
        sys.exit(1)
    
    user_conn = connector.connect(
        INSTANCE_CONNECTION_NAME,
        "pymysql",
        user=USER,
        password=PASSWORD,
        db=DATABASE,
    )
    
    with user_conn.cursor() as cursor:
        # Try to grant privileges (will fail if user doesn't have GRANT privilege)
        try:
            cursor.execute(f"GRANT ALL PRIVILEGES ON `{DATABASE}`.* TO %s@'%%'", (USER,))
            cursor.execute("FLUSH PRIVILEGES")
            user_conn.commit()
            print("✅ Permissions granted successfully!")
        except Exception as grant_error:
            print(f"❌ Cannot grant permissions: {grant_error}")
            print()
            print("The user doesn't have GRANT privilege.")
            print("You need to:")
            print("  1. Use root/admin user to grant permissions")
            print("  2. Or contact your database administrator")
            sys.exit(1)
    
    user_conn.close()
    connector.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

