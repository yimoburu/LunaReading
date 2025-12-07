#!/usr/bin/env python3
"""
Verify Cloud Run service database connection

This script checks if the Cloud Run service is successfully connected to Cloud SQL.

⚠️  DEPRECATED: This script uses SQLAlchemy for testing. It should be updated to use
   Cloud SQL Connector instead. The application no longer uses SQLAlchemy.
"""

import subprocess
import sys
import json
import re


def get_service_url(service_name, region, project_id):
    """Get Cloud Run service URL"""
    try:
        result = subprocess.run(
            ['gcloud', 'run', 'services', 'describe', service_name,
             '--region', region,
             '--project', project_id,
             '--format', 'value(status.url)'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_service_env_vars(service_name, region, project_id):
    """Get environment variables from Cloud Run service"""
    try:
        result = subprocess.run(
            ['gcloud', 'run', 'services', 'describe', service_name,
             '--region', region,
             '--project', project_id,
             '--format', 'json'],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(result.stdout)
        
        env_vars = {}
        containers = data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
        if containers:
            for env in containers[0].get('env', []):
                env_vars[env.get('name')] = env.get('value')
        
        return env_vars
    except Exception as e:
        print(f"⚠️  Could not get environment variables: {e}")
        return {}


def get_recent_logs(service_name, region, project_id, limit=50):
    """Get recent logs from Cloud Run service"""
    try:
        result = subprocess.run(
            ['gcloud', 'run', 'services', 'logs', 'read', service_name,
             '--region', region,
             '--project', project_id,
             '--limit', str(limit)],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError:
        return None


def test_sqlalchemy_connection(connection_string, database_name=None):
    """
    Test SQLAlchemy connection to Cloud SQL
    
    Args:
        connection_string: SQLAlchemy connection string
        database_name: Optional database name to verify
        
    Returns:
        tuple: (success: bool, message: str, details: dict)
    """
    try:
        from sqlalchemy import create_engine, text
        from sqlalchemy.engine.url import make_url
        from sqlalchemy.exc import OperationalError, SQLAlchemyError
        from urllib.parse import unquote
    except ImportError:
        return False, "SQLAlchemy not installed", {
            'error': 'ImportError',
            'solution': 'Install: pip install sqlalchemy pymysql'
        }
    
    # Parse connection string to extract unix_socket
    connect_args = {"connect_timeout": 10}
    unix_socket_used = False
    
    try:
        url = make_url(connection_string)
        
        # Extract unix_socket from query parameters if present
        # SQLAlchemy doesn't automatically pass this to PyMySQL
        if 'unix_socket' in url.query:
            unix_socket = url.query['unix_socket']
            # Decode URL-encoded path if needed
            unix_socket = unquote(unix_socket)
            connect_args['unix_socket'] = unix_socket
            unix_socket_used = True
            print(f"   Using Unix socket: {unix_socket}")
        else:
            print("   No Unix socket found in connection string")
        
        print("   Creating SQLAlchemy engine...")
        engine = create_engine(
            connection_string,
            pool_pre_ping=True,
            connect_args=connect_args
        )
        
        print("   Attempting to connect...")
        with engine.connect() as conn:
            # Test basic query
            result = conn.execute(text("SELECT 1 as test, DATABASE() as current_db, VERSION() as version"))
            row = result.fetchone()
            
            if row and row[0] == 1:
                details = {
                    'current_database': row[1],
                    'mysql_version': row[2] if len(row) > 2 else 'unknown'
                }
                
                # Test specific database if provided
                if database_name:
                    try:
                        conn.execute(text(f"USE {database_name}"))
                        conn.execute(text("SELECT 1"))
                        details['database_accessible'] = True
                        details['database_name'] = database_name
                    except Exception as db_err:
                        details['database_accessible'] = False
                        details['database_error'] = str(db_err)
                
                # Test table existence (check for common tables)
                try:
                    result = conn.execute(text("SHOW TABLES"))
                    tables = [row[0] for row in result.fetchall()]
                    details['tables'] = tables
                    details['table_count'] = len(tables)
                except Exception:
                    details['tables'] = []
                
                return True, "Connection successful", details
            else:
                return False, "Connection test query failed", {}
                
    except OperationalError as e:
        error_str = str(e).lower()
        details = {'error_type': 'OperationalError', 'error': str(e)}
        
        if "can't connect" in error_str or "cannot connect" in error_str:
            details['issue'] = 'connection_failed'
            # Check if we're trying to use unix_socket
            if unix_socket_used:
                details['note'] = 'Unix socket connection only works on Cloud Run, not locally'
                details['solution'] = 'This test should be run on Cloud Run or use Cloud SQL Proxy locally'
                details['unix_socket_path'] = connect_args.get('unix_socket', 'unknown')
            elif "localhost" in error_str or "127.0.0.1" in error_str:
                details['note'] = 'Trying to connect to localhost - Unix socket may not be configured correctly'
                details['solution'] = 'Check that unix_socket parameter is in connection string and passed to PyMySQL'
            else:
                details['note'] = 'Connection failed - check Cloud SQL instance status and network configuration'
        elif "access denied" in error_str or "authentication" in error_str:
            details['issue'] = 'authentication_failed'
            details['solution'] = 'Check username and password'
        elif "unknown database" in error_str:
            details['issue'] = 'database_not_found'
            if database_name:
                details['solution'] = f'Create database: gcloud sql databases create {database_name} --instance=INSTANCE_NAME'
        else:
            details['issue'] = 'operational_error'
        
        return False, f"Connection failed: {e}", details
        
    except SQLAlchemyError as e:
        return False, f"SQLAlchemy error: {e}", {
            'error_type': 'SQLAlchemyError',
            'error': str(e)
        }
        
    except Exception as e:
        return False, f"Unexpected error: {e}", {
            'error_type': 'Exception',
            'error': str(e)
        }


def check_database_connection_in_logs(logs):
    """Check logs for database connection status"""
    if not logs:
        return None
    
    # Look for database-related messages
    db_messages = []
    
    patterns = [
        (r'✅.*[Dd]atabase.*successful', 'success'),
        (r'✅.*[Dd]atabase.*MySQL', 'success'),
        (r'❌.*[Dd]atabase.*[Ff]ail', 'failure'),
        (r'⚠️.*[Dd]atabase.*[Ww]arning', 'warning'),
        (r'[Dd]atabase.*connection.*successful', 'success'),
        (r'[Cc]an\'t connect.*MySQL', 'failure'),
        (r'[Oo]perationalError', 'failure'),
        (r'SQLAlchemy.*error', 'failure'),
    ]
    
    for line in logs.split('\n'):
        for pattern, status in patterns:
            if re.search(pattern, line, re.IGNORECASE):
                db_messages.append((status, line.strip()))
    
    return db_messages


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Verify Cloud Run database connection')
    parser.add_argument('--service', default='lunareading-backend', help='Cloud Run service name')
    parser.add_argument('--region', default='us-central1', help='Cloud Run region')
    parser.add_argument('--project-id', help='Google Cloud project ID')
    
    args = parser.parse_args()
    
    # Get project ID
    if not args.project_id:
        try:
            result = subprocess.run(
                ['gcloud', 'config', 'get-value', 'project'],
                capture_output=True,
                text=True,
                check=True
            )
            args.project_id = result.stdout.strip()
        except:
            print("❌ Project ID not specified and gcloud not configured")
            sys.exit(1)
    
    print("🔍 Verifying Cloud Run Database Connection")
    print("=" * 50)
    print("")
    
    # Get service URL
    service_url = get_service_url(args.service, args.region, args.project_id)
    if service_url:
        print(f"✅ Service URL: {service_url}")
    else:
        print(f"⚠️  Could not get service URL")
    print("")
    
    # Check environment variables
    print("📋 Checking environment variables...")
    env_vars = get_service_env_vars(args.service, args.region, args.project_id)
    
    if 'SQLALCHEMY_DATABASE_URI' in env_vars:
        db_uri = env_vars['SQLALCHEMY_DATABASE_URI']
        # Mask password
        masked_uri = re.sub(r':([^:@/]+)@', r':***@', db_uri)
        print(f"✅ SQLALCHEMY_DATABASE_URI is set")
        print(f"   {masked_uri[:80]}...")
        
        # Check if it's Cloud SQL
        if 'cloudsql' in db_uri.lower():
            print("   ✅ Using Cloud SQL (Unix socket)")
        elif 'mysql' in db_uri.lower():
            print("   ✅ Using MySQL")
        else:
            print("   ⚠️  Unexpected database type")
    else:
        print("❌ SQLALCHEMY_DATABASE_URI not found in environment variables")
    print("")
    
    # Check Cloud SQL instances
    print("📋 Checking Cloud SQL instance configuration...")
    try:
        # Get full service JSON to check multiple possible locations
        result = subprocess.run(
            ['gcloud', 'run', 'services', 'describe', args.service,
             '--region', args.region,
             '--project', args.project_id,
             '--format', 'json'],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(result.stdout)
        
        # Check multiple possible locations for Cloud SQL instances
        template_spec = data.get('spec', {}).get('template', {}).get('spec', {})
        
        # Location 1: In containers[0].cloudSqlInstances
        containers = template_spec.get('containers', [])
        instances_from_container = []
        if containers:
            instances_from_container = containers[0].get('cloudSqlInstances', [])
        
        # Location 2: In template.spec.cloudSqlInstances (top level)
        instances_from_spec = template_spec.get('cloudSqlInstances', [])
        
        # Location 3: Check if connection string indicates Cloud SQL
        db_uri = env_vars.get('SQLALCHEMY_DATABASE_URI', '')
        connection_name_from_uri = None
        if 'unix_socket=/cloudsql/' in db_uri:
            # Extract connection name from URI
            try:
                conn_part = db_uri.split('unix_socket=/cloudsql/')[1]
                connection_name_from_uri = conn_part.split('?')[0] if '?' in conn_part else conn_part.split('&')[0]
                # Decode URL encoding
                from urllib.parse import unquote
                connection_name_from_uri = unquote(connection_name_from_uri)
            except:
                pass
        
        # Combine all sources
        all_instances = list(set(instances_from_container + instances_from_spec))
        if connection_name_from_uri and connection_name_from_uri not in all_instances:
            all_instances.append(connection_name_from_uri)
        
        if all_instances:
            print(f"✅ Cloud SQL instances configured: {', '.join(all_instances)}")
        elif connection_name_from_uri:
            print(f"✅ Cloud SQL connection detected in URI: {connection_name_from_uri}")
            print("   (Instance should be added via --add-cloudsql-instances flag)")
        else:
            print("⚠️  No Cloud SQL instances found in service configuration")
            print("   Note: The connection string uses Unix socket, which requires")
            print("   the instance to be added with: --add-cloudsql-instances")
    except Exception as e:
        print(f"⚠️  Could not check Cloud SQL instances: {e}")
    print("")
    
    # Test SQLAlchemy connection
    if 'SQLALCHEMY_DATABASE_URI' in env_vars:
        print("🧪 Testing SQLAlchemy connection...")
        print("")
        
        db_uri = env_vars['SQLALCHEMY_DATABASE_URI']
        
        # Extract database name from URI if not already known
        test_db_name = None
        if 'cloudsql' in db_uri.lower() or 'mysql' in db_uri.lower():
            # Try to extract database name from connection string
            try:
                if '@/' in db_uri:
                    db_part = db_uri.split('@/')[1]
                    test_db_name = db_part.split('?')[0] if '?' in db_part else db_part.split('&')[0]
            except:
                pass
        
        success, message, details = test_sqlalchemy_connection(db_uri, test_db_name)
        
        if success:
            print(f"   ✅ {message}")
            if details:
                if 'current_database' in details:
                    print(f"   📊 Current database: {details['current_database']}")
                if 'mysql_version' in details:
                    print(f"   📊 MySQL version: {details['mysql_version']}")
                if 'database_accessible' in details:
                    if details['database_accessible']:
                        print(f"   ✅ Database '{details.get('database_name', 'N/A')}' is accessible")
                    else:
                        print(f"   ⚠️  Database '{details.get('database_name', 'N/A')}' issue: {details.get('database_error', 'N/A')}")
                if 'table_count' in details:
                    print(f"   📊 Tables found: {details['table_count']}")
                    if details.get('tables'):
                        print(f"   📋 Tables: {', '.join(details['tables'][:10])}")
                        if len(details['tables']) > 10:
                            print(f"      ... and {len(details['tables']) - 10} more")
        else:
            print(f"   ❌ {message}")
            if details:
                if details.get('issue') == 'connection_failed':
                    print("   💡 This is expected if testing locally (Unix socket only works on Cloud Run)")
                    print("   💡 The connection string format is correct for Cloud Run deployment")
                elif details.get('solution'):
                    print(f"   💡 Solution: {details['solution']}")
        print("")
    else:
        print("⚠️  Cannot test SQLAlchemy connection (SQLALCHEMY_DATABASE_URI not found)")
        print("")
    
    # Check logs
    print("📋 Checking recent logs for database connection status...")
    logs = get_recent_logs(args.service, args.region, args.project_id, limit=100)
    
    if logs:
        db_messages = check_database_connection_in_logs(logs)
        
        if db_messages:
            print("   Database-related log messages:")
            for status, message in db_messages[-5:]:  # Show last 5
                if status == 'success':
                    print(f"   ✅ {message}")
                elif status == 'failure':
                    print(f"   ❌ {message}")
                else:
                    print(f"   ⚠️  {message}")
        else:
            print("   ℹ️  No recent database connection messages in logs")
            print("   (Service may still be starting or logs may be delayed)")
    else:
        print("   ⚠️  Could not fetch logs")
    
    print("")
    print("💡 To view full logs:")
    print(f"   gcloud run services logs read {args.service} --region {args.region} --limit 100")
    print("")
    print("💡 To test the service:")
    if service_url:
        print(f"   curl {service_url}/")


if __name__ == '__main__':
    main()

