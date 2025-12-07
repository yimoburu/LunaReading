#!/usr/bin/env python3
"""
Update Cloud Run service to use Cloud SQL MySQL

This script:
1. Reads Cloud SQL connection information
2. Updates Cloud Run service with Cloud SQL Connector environment variables

⚠️  DEPRECATED: This script uses SQLAlchemy for testing. It should be updated to use
   Cloud SQL Connector instead. The application no longer uses SQLAlchemy.
"""

import os
import sys
import subprocess
import re
from pathlib import Path
from urllib.parse import quote, quote_plus


def get_gcloud_config():
    """Get gcloud project ID"""
    try:
        result = subprocess.run(
            ['gcloud', 'config', 'get-value', 'project'],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None


def get_connection_name(instance_name, project_id):
    """Get Cloud SQL connection name"""
    try:
        result = subprocess.run(
            ['gcloud', 'sql', 'instances', 'describe', instance_name,
             '--project', project_id,
             '--format', 'value(connectionName)'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"❌ Could not find Cloud SQL instance: {instance_name}")
        print(f"   Error: {e.stderr}")
        sys.exit(1)


def read_cloudsql_config():
    """Read Cloud SQL configuration from .cloudsql_user_password file"""
    config_file = Path('.cloudsql_user_password')
    
    if not config_file.exists():
        print("❌ Database user password file not found (.cloudsql_user_password)")
        print("   Run setup_cloud_sql.sh first")
        sys.exit(1)
    
    config = {}
    with open(config_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            # Parse key=value lines
            if '=' in line:
                key, value = line.split('=', 1)
                config[key] = value
            else:
                # Last line without key= is the password
                if 'password' not in config:
                    config['password'] = line
    
    # Extract values
    db_user = config.get('DB_USER', 'lunareading_user')
    database_name = config.get('DATABASE_NAME', 'lunareading')
    connection_name = config.get('CONNECTION_NAME', '')
    password = config.get('password', '')
    
    if not password:
        print("❌ Could not read database password from .cloudsql_user_password")
        sys.exit(1)
    
    return {
        'user': db_user,
        'database': database_name,
        'connection_name': connection_name,
        'password': password
    }


def build_connection_string(user, password, database, connection_name):
    """Build properly URL-encoded connection string"""
    # URL encode password and connection name
    encoded_pwd = quote_plus(password)
    encoded_conn = quote(connection_name, safe='')
    
    connection_string = (
        f"mysql+pymysql://{user}:{encoded_pwd}@/{database}"
        f"?unix_socket=/cloudsql/{encoded_conn}"
    )
    
    return connection_string


def test_sqlalchemy_connection(connection_string, database_name):
    """Test SQLAlchemy connection to Cloud SQL"""
    print("🧪 Testing SQLAlchemy connection...")
    print("")
    
    try:
        from sqlalchemy import create_engine, text
        from sqlalchemy.exc import OperationalError, SQLAlchemyError
    except ImportError as e:
        print(f"   ⚠️  Cannot test connection: {e}")
        print("   💡 Install dependencies: pip install sqlalchemy pymysql")
        print("   💡 Continuing anyway - connection string format looks correct")
        return False
    
    try:
        print("   Creating SQLAlchemy engine...")
        engine = create_engine(
            connection_string,
            pool_pre_ping=True,
            connect_args={"connect_timeout": 10}
        )
        
        print("   Attempting to connect...")
        with engine.connect() as conn:
            # Test query
            result = conn.execute(text("SELECT 1 as test"))
            row = result.fetchone()
            
            if row and row[0] == 1:
                print("   ✅ Connection successful!")
                print("   ✅ SQLAlchemy can connect to Cloud SQL")
                
                # Test database exists
                try:
                    conn.execute(text(f"USE {database_name}"))
                    print(f"   ✅ Database '{database_name}' exists and is accessible")
                except Exception as db_err:
                    print(f"   ⚠️  Warning: Database '{database_name}' issue: {db_err}")
                
                return True
            else:
                print("   ❌ Connection test query failed")
                return False
                
    except OperationalError as e:
        error_str = str(e).lower()
        print(f"   ❌ Connection failed: {e}")
        
        if "can't connect" in error_str or "cannot connect" in error_str:
            print("   💡 This is expected if testing locally (Unix socket only works on Cloud Run)")
            print("   💡 The connection string format is correct for Cloud Run deployment")
        elif "access denied" in error_str or "authentication" in error_str:
            print("   ❌ Authentication failed - check username and password")
        elif "unknown database" in error_str:
            print(f"   ❌ Database '{database_name}' does not exist")
            print(f"   💡 Create it: gcloud sql databases create {database_name} --instance=INSTANCE_NAME")
        else:
            print(f"   ❌ Connection error: {e}")
        
        return False
        
    except SQLAlchemyError as e:
        print(f"   ❌ SQLAlchemy error: {e}")
        return False
        
    except Exception as e:
        print(f"   ❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False


def update_cloud_run_service(region, project_id, connection_name, connection_string):
    """Update Cloud Run service with new connection string"""
    print("Updating backend service...")
    
    try:
        # Add Cloud SQL instance and update environment variable
        subprocess.run(
            [
                'gcloud', 'run', 'services', 'update', 'lunareading-backend',
                '--region', region,
                '--add-cloudsql-instances', connection_name,
                '--update-env-vars', f'SQLALCHEMY_DATABASE_URI={connection_string}',
                '--project', project_id
            ],
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to update Cloud Run service: {e}")
        return False


def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Update Cloud Run service to use Cloud SQL MySQL'
    )
    parser.add_argument(
        '--region',
        default='us-central1',
        help='Cloud Run region (default: us-central1)'
    )
    parser.add_argument(
        '--project-id',
        help='Google Cloud project ID (default: from gcloud config)'
    )
    parser.add_argument(
        '--instance-name',
        default='free-trial-first-project',
        help='Cloud SQL instance name (default: free-trial-first-project)'
    )
    parser.add_argument(
        '--skip-test',
        action='store_true',
        help='Skip SQLAlchemy connection test'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Continue even if connection test fails'
    )
    
    args = parser.parse_args()
    
    # Get project ID
    project_id = args.project_id or get_gcloud_config()
    if not project_id:
        print("❌ Project ID not specified")
        print("   Usage: python update_cloud_run_db.py [--project-id PROJECT_ID] [--region REGION]")
        print("   Or set: gcloud config set project PROJECT_ID")
        sys.exit(1)
    
    print("🔄 Updating Cloud Run service to use Cloud SQL")
    print("=" * 50)
    print("")
    
    # Get connection name
    connection_name = get_connection_name(args.instance_name, project_id)
    print(f"Connection Name: {connection_name}")
    print("")
    
    # Read Cloud SQL config
    config = read_cloudsql_config()
    
    # Use connection name from gcloud if not in config file
    if not config['connection_name']:
        config['connection_name'] = connection_name
    
    # Build connection string
    connection_string = build_connection_string(
        config['user'],
        config['password'],
        config['database'],
        config['connection_name']
    )
    
    print("Connection string (masked):")
    masked_uri = connection_string.replace(config['password'], '***')
    print(f"  {masked_uri}")
    print("")
    
    # Test connection
    test_passed = False
    if not args.skip_test:
        test_passed = test_sqlalchemy_connection(connection_string, config['database'])
        print("")
        
        if test_passed:
            print("✅ Connection test passed - ready to update Cloud Run")
            print("")
        else:
            print("⚠️  Connection test failed")
            if not args.force:
                print("   This might be expected if testing locally (Unix socket only works on Cloud Run)")
                print("   The connection string format is correct for Cloud Run deployment")
                print("")
                response = input("   Continue with Cloud Run update? (y/n): ").strip().lower()
                if response != 'y':
                    print("   Update cancelled")
                    sys.exit(0)
            print("")
    else:
        print("⚠️  Skipping connection test (--skip-test)")
        print("")
    
    # Update Cloud Run service
    if update_cloud_run_service(args.region, project_id, connection_name, connection_string):
        print("")
        print("✅ Cloud Run service updated!")
        print("")
        print("The service will now use Cloud SQL MySQL.")
        print("")
        print("⚠️  Note: You may need to restart the service or wait for it to scale to zero")
        print("   and start a new instance for the changes to take effect.")
    else:
        print("")
        print("❌ Failed to update Cloud Run service")
        sys.exit(1)


if __name__ == '__main__':
    main()

