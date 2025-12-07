#!/usr/bin/env python3
"""
Direct database connection test script
Tests Cloud SQL connection and basic operations without Flask
"""

import os
import sys
import traceback
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from backend.cloudsql_client import CloudSQLClient
from backend.config import Config


def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)


def print_result(success, message):
    """Print a formatted result"""
    status = "✅" if success else "❌"
    print(f"{status} {message}")


def test_connection():
    """Test basic database connection"""
    print_section("Test 1: Database Connection")
    
    try:
        print("Initializing Cloud SQL client...")
        print(f"  Instance: {Config.CLOUDSQL_INSTANCE_CONNECTION_NAME}")
        print(f"  Database: {Config.CLOUDSQL_DATABASE}")
        print(f"  User: {Config.CLOUDSQL_USER}")
        
        client = CloudSQLClient(
            instance_connection_name=Config.CLOUDSQL_INSTANCE_CONNECTION_NAME,
            database=Config.CLOUDSQL_DATABASE,
            user=Config.CLOUDSQL_USER,
            password=Config.CLOUDSQL_PASSWORD
        )
        
        print_result(True, "Cloud SQL client initialized successfully")
        return client
    except Exception as e:
        print_result(False, f"Failed to initialize client: {str(e)}")
        traceback.print_exc()
        return None


def test_simple_query(client):
    """Test a simple SELECT query"""
    print_section("Test 2: Simple Query")
    
    try:
        with client.get_connection() as conn:
            cursor = conn.cursor()
            # Use backticks to escape reserved keyword, or use different alias
            cursor.execute("SELECT 1 as test_value, DATABASE() as current_db, USER() as db_user")
            result = cursor.fetchone()
            cursor.close()
            
            print_result(True, "Query executed successfully")
            print(f"  Test value: {result[0]}")
            print(f"  Current database: {result[1]}")
            print(f"  Database user: {result[2]}")
            return True
    except Exception as e:
        print_result(False, f"Query failed: {str(e)}")
        traceback.print_exc()
        return False


def test_table_exists(client):
    """Test if users table exists"""
    print_section("Test 3: Check Tables")
    
    try:
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT TABLE_NAME 
                FROM information_schema.TABLES 
                WHERE TABLE_SCHEMA = %s
                ORDER BY TABLE_NAME
            """, (Config.CLOUDSQL_DATABASE,))
            tables = cursor.fetchall()
            cursor.close()
            
            table_names = [table[0] for table in tables]
            print_result(True, f"Found {len(table_names)} table(s)")
            
            required_tables = ['users', 'reading_sessions', 'questions', 'answers']
            for table in required_tables:
                if table in table_names:
                    print(f"  ✅ {table} exists")
                else:
                    print(f"  ❌ {table} missing")
            
            if 'users' in table_names:
                return True
            else:
                print_result(False, "Users table not found")
                return False
    except Exception as e:
        print_result(False, f"Failed to check tables: {str(e)}")
        traceback.print_exc()
        return False


def test_user_query(client):
    """Test querying users table"""
    print_section("Test 4: Query Users Table")
    
    try:
        user_count = 0
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM users")
            user_count = cursor.fetchone()[0]
            cursor.close()
        
        print_result(True, f"Users table is accessible")
        print(f"  Total users: {user_count}")
        return True
    except Exception as e:
        print_result(False, f"Failed to query users table: {str(e)}")
        traceback.print_exc()
        return False


def test_user_insert(client):
    """Test inserting a test user"""
    print_section("Test 5: Insert Test User")
    
    try:
        test_username = f"test_user_{os.getpid()}_{int(__import__('time').time())}"
        test_email = f"{test_username}@test.example.com"
        test_password_hash = "test_hash_12345"
        test_grade = 3
        test_reading_level = 2.4
        
        print(f"  Inserting test user: {test_username}")
        user_id = client.insert_user(
            username=test_username,
            email=test_email,
            password_hash=test_password_hash,
            grade_level=test_grade,
            reading_level=test_reading_level
        )
        
        print_result(True, f"User inserted successfully")
        print(f"  User ID: {user_id}")
        
        # Verify the user was inserted
        user = client.get_user_by_id(user_id)
        if user:
            print_result(True, "User retrieved successfully")
            print(f"  Username: {user['username']}")
            print(f"  Email: {user['email']}")
            print(f"  Grade: {user['grade_level']}")
            
            # Clean up - delete test user
            print(f"\n  Cleaning up test user...")
            with client.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
                conn.commit()
                cursor.close()
            print_result(True, "Test user deleted")
        else:
            print_result(False, "Failed to retrieve inserted user")
            return False
        
        return True
    except Exception as e:
        print_result(False, f"Insert test failed: {str(e)}")
        traceback.print_exc()
        return False


def test_user_lookup(client):
    """Test user lookup methods"""
    print_section("Test 6: User Lookup Methods")
    
    try:
        # Get first user if exists
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, username, email FROM users LIMIT 1")
            result = cursor.fetchone()
            cursor.close()
        
        if result:
            user_id, username, email = result
            print(f"  Testing with user: {username} (ID: {user_id})")
            
            # Test get_user_by_id
            user = client.get_user_by_id(user_id)
            if user:
                print_result(True, "get_user_by_id() works")
            else:
                print_result(False, "get_user_by_id() returned None")
                return False
            
            # Test get_user_by_username
            user = client.get_user_by_username(username)
            if user:
                print_result(True, "get_user_by_username() works")
            else:
                print_result(False, "get_user_by_username() returned None")
                return False
            
            # Test get_user_by_email
            user = client.get_user_by_email(email)
            if user:
                print_result(True, "get_user_by_email() works")
            else:
                print_result(False, "get_user_by_email() returned None")
                return False
            
            return True
        else:
            print("  ⚠️  No users in database to test lookup")
            print("  Creating a temporary test user...")
            
            test_username = f"lookup_test_{os.getpid()}"
            test_email = f"{test_username}@test.example.com"
            test_user_id = client.insert_user(
                username=test_username,
                email=test_email,
                password_hash="test",
                grade_level=3,
                reading_level=2.4
            )
            
            # Test lookups
            user = client.get_user_by_id(test_user_id)
            print_result(user is not None, "get_user_by_id() works")
            
            user = client.get_user_by_username(test_username)
            print_result(user is not None, "get_user_by_username() works")
            
            user = client.get_user_by_email(test_email)
            print_result(user is not None, "get_user_by_email() works")
            
            # Clean up
            with client.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM users WHERE id = %s", (test_user_id,))
                conn.commit()
                cursor.close()
            
            return True
    except Exception as e:
        print_result(False, f"Lookup test failed: {str(e)}")
        traceback.print_exc()
        return False


def test_connection_pooling(client):
    """Test multiple connections"""
    print_section("Test 7: Connection Pooling")
    
    try:
        print("  Testing multiple sequential connections...")
        for i in range(3):
            with client.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
                cursor.close()
            print(f"    Connection {i+1}: ✅")
        
        print_result(True, "Multiple connections work correctly")
        return True
    except Exception as e:
        print_result(False, f"Connection pooling test failed: {str(e)}")
        traceback.print_exc()
        return False


def main():
    """Run all tests"""
    print("\n" + "=" * 60)
    print("  Direct Database Connection Test")
    print("=" * 60)
    print("\nThis script tests the Cloud SQL connection directly")
    print("without going through the Flask application.\n")
    
    # Check configuration
    print_section("Configuration Check")
    if not Config.CLOUDSQL_INSTANCE_CONNECTION_NAME:
        print_result(False, "CLOUDSQL_INSTANCE_CONNECTION_NAME not set")
        print("\nPlease set environment variables or create .env file")
        sys.exit(1)
    
    if not Config.CLOUDSQL_USER:
        print_result(False, "CLOUDSQL_USER not set")
        sys.exit(1)
    
    if not Config.CLOUDSQL_PASSWORD:
        print_result(False, "CLOUDSQL_PASSWORD not set")
        sys.exit(1)
    
    print_result(True, "Configuration loaded")
    print(f"  Instance: {Config.CLOUDSQL_INSTANCE_CONNECTION_NAME}")
    print(f"  Database: {Config.CLOUDSQL_DATABASE}")
    print(f"  User: {Config.CLOUDSQL_USER}")
    
    # Run tests
    results = {}
    
    client = test_connection()
    results['connection'] = client is not None
    
    if not client:
        print("\n❌ Cannot continue - connection failed")
        print("\n💡 Troubleshooting:")
        print("  1. Verify Cloud SQL instance is running")
        print("  2. Check environment variables are set correctly")
        print("  3. For Cloud Run: ensure --add-cloudsql-instances is set")
        print("  4. For local: ensure Cloud SQL Proxy is running or use Cloud SQL Connector")
        sys.exit(1)
    
    results['simple_query'] = test_simple_query(client)
    results['table_exists'] = test_table_exists(client)
    results['user_query'] = test_user_query(client)
    results['user_insert'] = test_user_insert(client)
    results['user_lookup'] = test_user_lookup(client)
    results['connection_pooling'] = test_connection_pooling(client)
    
    # Summary
    print_section("Test Summary")
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}: {test_name}")
    
    print(f"\nResults: {passed}/{total} tests passed")
    
    if passed == total:
        print_result(True, "All tests passed! Database connection is working correctly.")
        return 0
    else:
        print_result(False, f"{total - passed} test(s) failed. Check errors above.")
        return 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
        traceback.print_exc()
        sys.exit(1)

