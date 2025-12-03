#!/usr/bin/env python3
"""
Query Database on Google Cloud Run
Supports both SQLite (ephemeral) and Cloud SQL (persistent)
"""

import subprocess
import sys
import os
import json
from pathlib import Path

def run_gcloud_command(cmd, capture_output=True):
    """Run a gcloud command and return result"""
    try:
        result = subprocess.run(
            ['gcloud'] + cmd,
            capture_output=capture_output,
            text=True,
            check=False
        )
        return result.returncode == 0, result.stdout, result.stderr
    except FileNotFoundError:
        return False, "", "gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"

def get_service_info(service_name, region):
    """Get Cloud Run service information"""
    success, stdout, stderr = run_gcloud_command([
        'run', 'services', 'describe', service_name,
        '--region', region,
        '--format', 'json'
    ])
    
    if not success:
        return None
    
    try:
        return json.loads(stdout)
    except:
        return None

def get_env_vars(service_name, region):
    """Get environment variables from Cloud Run service"""
    service_info = get_service_info(service_name, region)
    if not service_info:
        return {}
    
    env_vars = {}
    for env_var in service_info.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('env', []):
        env_vars[env_var['name']] = env_var.get('value', '')
    
    return env_vars

def detect_database_type(service_name, region):
    """Detect if using SQLite or Cloud SQL"""
    env_vars = get_env_vars(service_name, region)
    db_uri = env_vars.get('SQLALCHEMY_DATABASE_URI', '')
    
    if 'cloudsql' in db_uri.lower() or 'postgresql' in db_uri.lower() or 'mysql' in db_uri.lower():
        return 'cloudsql', db_uri
    elif 'sqlite' in db_uri.lower():
        return 'sqlite', db_uri
    else:
        return 'unknown', db_uri

def query_sqlite_cloud_run(service_name, region, query, db_path='/tmp/lunareading.db'):
    """Query SQLite database in Cloud Run container"""
    print(f"📦 Querying SQLite database in Cloud Run container...")
    print(f"   Service: {service_name}")
    print(f"   Database: {db_path}")
    print()
    
    # Create a temporary Python script to execute in the container
    script = f"""
import sqlite3
import sys
import json

try:
    conn = sqlite3.connect('{db_path}')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('''{query}''')
    
    if query.strip().upper().startswith('SELECT'):
        rows = cursor.fetchall()
        result = [dict(row) for row in rows]
        print(json.dumps(result, indent=2, default=str))
    else:
        conn.commit()
        print(json.dumps({{'affected': cursor.rowcount}}))
    conn.close()
except Exception as e:
    print(json.dumps({{'error': str(e)}}), file=sys.stderr)
    sys.exit(1)
"""
    
    # Execute in container
    success, stdout, stderr = run_gcloud_command([
        'run', 'services', 'exec', service_name,
        '--region', region,
        '--command', f"python3 -c {repr(script)}"
    ], capture_output=True)
    
    if not success:
        print(f"❌ Error executing query in container:")
        print(stderr)
        return None
    
    try:
        result = json.loads(stdout)
        if 'error' in result:
            print(f"❌ Database error: {result['error']}")
            return None
        return result
    except:
        print(f"✅ Query executed")
        print(stdout)
        return stdout

def query_cloud_sql(instance_name, database_name, query, user='root'):
    """Query Cloud SQL database"""
    print(f"☁️  Querying Cloud SQL database...")
    print(f"   Instance: {instance_name}")
    print(f"   Database: {database_name}")
    print()
    
    # Use gcloud sql connect
    print("⚠️  Cloud SQL query requires interactive connection.")
    print("   Use one of these methods:")
    print()
    print("   1. Connect via gcloud:")
    print(f"      gcloud sql connect {instance_name} --user={user} --database={database_name}")
    print()
    print("   2. Use Cloud SQL Proxy:")
    print("      # Install proxy: https://cloud.google.com/sql/docs/mysql/sql-proxy")
    print(f"      cloud_sql_proxy -instances=PROJECT:REGION:{instance_name}=tcp:3306")
    print("      # Then connect with: mysql -u root -p -h 127.0.0.1")
    print()
    print("   3. Use the local query_db.py tool with Cloud SQL connection string")
    print()
    return None

def list_tables_sqlite(service_name, region, db_path='/tmp/lunareading.db'):
    """List all tables in SQLite database"""
    query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    result = query_sqlite_cloud_run(service_name, region, query, db_path)
    
    if result and isinstance(result, list):
        print("\n📊 Tables in database:")
        for table in result:
            print(f"  - {table.get('name', '')}")
        return [t.get('name', '') for t in result]
    return []

def show_schema_sqlite(service_name, region, table_name, db_path='/tmp/lunareading.db'):
    """Show schema for a table"""
    query = f"PRAGMA table_info({table_name})"
    result = query_sqlite_cloud_run(service_name, region, query, db_path)
    
    if result and isinstance(result, list):
        print(f"\n📋 Schema for '{table_name}':")
        print(f"{'Column':<20} {'Type':<15} {'Nullable':<10} {'Primary Key':<12}")
        print("-" * 60)
        for col in result:
            nullable = "No" if col.get('notnull', 0) else "Yes"
            pk = "Yes" if col.get('pk', 0) else "No"
            print(f"{col.get('name', ''):<20} {col.get('type', ''):<15} {nullable:<10} {pk:<12}")
    return result

def interactive_mode(service_name, region):
    """Interactive query mode"""
    print("\n" + "="*60)
    print("🔍 Cloud Database Query Tool - Interactive Mode")
    print("="*60)
    
    # Detect database type
    db_type, db_uri = detect_database_type(service_name, region)
    print(f"\n📊 Database Type: {db_type.upper()}")
    print(f"   URI: {db_uri}")
    
    if db_type == 'cloudsql':
        print("\n⚠️  Cloud SQL detected. Use Cloud SQL Proxy or gcloud sql connect.")
        query_cloud_sql('INSTANCE_NAME', 'DATABASE_NAME', '')
        return
    
    if db_type != 'sqlite':
        print(f"\n❌ Unknown database type: {db_type}")
        return
    
    # Extract database path
    db_path = '/tmp/lunareading.db'
    if 'sqlite:///' in db_uri:
        db_path = db_uri.replace('sqlite:///', '')
    
    print(f"\nCommands:")
    print("  tables        - List all tables")
    print("  schema <table>- Show table schema")
    print("  sql <query>   - Execute custom SQL query")
    print("  exit/quit     - Exit")
    print("\n" + "="*60)
    
    while True:
        try:
            command = input("\n> ").strip()
            
            if not command:
                continue
            
            if command.lower() in ['exit', 'quit', 'q']:
                print("\n👋 Goodbye!")
                break
            
            elif command.lower() == 'tables':
                list_tables_sqlite(service_name, region, db_path)
            
            elif command.lower().startswith('schema '):
                table = command.split(' ', 1)[1].strip()
                show_schema_sqlite(service_name, region, table, db_path)
            
            elif command.lower().startswith('sql '):
                query = command[4:].strip()
                result = query_sqlite_cloud_run(service_name, region, query, db_path)
                if result:
                    if isinstance(result, list):
                        print(f"\n✅ Results ({len(result)} rows):")
                        for i, row in enumerate(result[:10], 1):  # Show first 10
                            print(f"\nRow {i}:")
                            for key, value in row.items():
                                print(f"  {key}: {value}")
                        if len(result) > 10:
                            print(f"\n... and {len(result) - 10} more rows")
                    else:
                        print(result)
            
            else:
                print("❌ Unknown command. Type 'help' or 'exit'")
                
        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}")

def main():
    """Main function"""
    if len(sys.argv) < 3:
        print("Usage: query_cloud_db.py <service-name> <region> [query]")
        print()
        print("Examples:")
        print("  python3 scripts/query_cloud_db.py lunareading-backend us-central1")
        print("  python3 scripts/query_cloud_db.py lunareading-backend us-central1 'SELECT * FROM user LIMIT 5'")
        print()
        print("Service name is typically: lunareading-backend")
        sys.exit(1)
    
    service_name = sys.argv[1]
    region = sys.argv[2]
    query = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Check gcloud is available
    success, _, _ = run_gcloud_command(['--version'])
    if not success:
        print("❌ gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install")
        sys.exit(1)
    
    # Detect database type
    db_type, db_uri = detect_database_type(service_name, region)
    
    if query:
        # Execute single query
        if db_type == 'sqlite':
            db_path = '/tmp/lunareading.db'
            if 'sqlite:///' in db_uri:
                db_path = db_uri.replace('sqlite:///', '')
            result = query_sqlite_cloud_run(service_name, region, query, db_path)
            if result:
                print(json.dumps(result, indent=2, default=str))
        else:
            print(f"❌ Direct query not supported for {db_type}")
            print("   Use interactive mode or Cloud SQL connection methods")
    else:
        # Interactive mode
        interactive_mode(service_name, region)

if __name__ == '__main__':
    main()

