#!/usr/bin/env python3
"""
Database query test script
Tests various database queries used in the application
"""

import os
import sys
import traceback
import json
import time
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from backend.cloudsql_client import CloudSQLClient
from backend.config import Config

# Try to import requests for HTTP testing
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False


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
        
        # Test connection
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.close()
        
        print_result(True, "Database connection successful")
        return client
    except Exception as e:
        print_result(False, f"Database connection failed: {str(e)}")
        traceback.print_exc()
        return None


def test_user_queries(client):
    """Test user-related queries"""
    print_section("Test 2: User Queries")
    
    results = []
    
    try:
        # Test: Get all users
        print("\n2.1 Testing: Get all users")
        users = client.get_all_users()
        print_result(True, f"Retrieved {len(users)} user(s)")
        if users:
            print(f"   Sample user: {users[0].get('username', 'N/A')} (ID: {users[0].get('id', 'N/A')})")
        results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get all users: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Get user by ID (if users exist)
        if users and len(users) > 0:
            print("\n2.2 Testing: Get user by ID")
            test_user_id = users[0]['id']
            user = client.get_user_by_id(test_user_id)
            if user:
                print_result(True, f"Retrieved user: {user.get('username', 'N/A')}")
                print(f"   Email: {user.get('email', 'N/A')}")
                print(f"   Grade: {user.get('grade_level', 'N/A')}")
            else:
                print_result(False, f"User with ID {test_user_id} not found")
            results.append(user is not None)
        else:
            print("\n2.2 Skipping: No users found to test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get user by ID: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Get user by email (if users exist)
        if users and len(users) > 0:
            print("\n2.3 Testing: Get user by email")
            # test_email = users[0].get('email')
            test_email = "testb@gmail.com"
            if test_email:
                user = client.get_user_by_email(test_email)
                if user:
                    print_result(True, f"Retrieved user by email: {user.get('username', 'N/A')}")
                else:
                    print_result(False, f"User with email {test_email} not found")
                results.append(user is not None)
            else:
                print("\n2.3 Skipping: No email found")
                results.append(True)
        else:
            print("\n2.3 Skipping: No users found to test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get user by email: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    return all(results)


def test_session_queries(client):
    """Test session-related queries"""
    print_section("Test 3: Session Queries")
    
    results = []
    
    try:
        # Test: Get sessions by user (if users exist)
        print("\n3.1 Testing: Get sessions by user")
        users = client.get_all_users()
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            sessions = client.get_sessions_by_user(test_user_id)
            print_result(True, f"Retrieved {len(sessions)} session(s) for user {test_user_id}")
            if sessions:
                print(f"   Sample session: {sessions[0].get('book_title', 'N/A')} - Chapter {sessions[0].get('chapter', 'N/A')}")
            results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get sessions by user: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Get session by ID (if sessions exist)
        print("\n3.2 Testing: Get session by ID")
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            sessions = client.get_sessions_by_user(test_user_id)
            if sessions and len(sessions) > 0:
                test_session_id = sessions[0]['id']
                session = client.get_session_by_id(test_session_id, test_user_id)
                if session:
                    print_result(True, f"Retrieved session: {session.get('book_title', 'N/A')}")
                    print(f"   Chapter: {session.get('chapter', 'N/A')}")
                    print(f"   Total questions: {session.get('total_questions', 'N/A')}")
                else:
                    print_result(False, f"Session with ID {test_session_id} not found")
                results.append(session is not None)
            else:
                print("   No sessions found, skipping test")
                results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get session by ID: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    return all(results)


def test_question_queries(client):
    """Test question-related queries"""
    print_section("Test 4: Question Queries")
    
    results = []
    
    try:
        # Test: Get questions by session (if sessions exist)
        print("\n4.1 Testing: Get questions by session")
        users = client.get_all_users()
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            sessions = client.get_sessions_by_user(test_user_id)
            if sessions and len(sessions) > 0:
                test_session_id = sessions[0]['id']
                questions = client.get_questions_by_session(test_session_id)
                print_result(True, f"Retrieved {len(questions)} question(s) for session {test_session_id}")
                if questions:
                    print(f"   Sample question: {questions[0].get('question_text', 'N/A')[:50]}...")
                results.append(True)
            else:
                print("   No sessions found, skipping test")
                results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get questions by session: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Get question by ID (if questions exist)
        print("\n4.2 Testing: Get question by ID")
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            sessions = client.get_sessions_by_user(test_user_id)
            if sessions and len(sessions) > 0:
                test_session_id = sessions[0]['id']
                questions = client.get_questions_by_session(test_session_id)
                if questions and len(questions) > 0:
                    test_question_id = questions[0]['id']
                    question = client.get_question_by_id(test_question_id)
                    if question:
                        print_result(True, f"Retrieved question: {question.get('question_text', 'N/A')[:50]}...")
                    else:
                        print_result(False, f"Question with ID {test_question_id} not found")
                    results.append(question is not None)
                else:
                    print("   No questions found, skipping test")
                    results.append(True)
            else:
                print("   No sessions found, skipping test")
                results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get question by ID: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    return all(results)


def test_answer_queries(client):
    """Test answer-related queries"""
    print_section("Test 5: Answer Queries")
    
    results = []
    
    try:
        # Test: Get answers by question (if questions exist)
        print("\n5.1 Testing: Get answers by question")
        users = client.get_all_users()
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            sessions = client.get_sessions_by_user(test_user_id)
            if sessions and len(sessions) > 0:
                test_session_id = sessions[0]['id']
                questions = client.get_questions_by_session(test_session_id)
                if questions and len(questions) > 0:
                    test_question_id = questions[0]['id']
                    answers = client.get_answers_by_question(test_question_id)
                    print_result(True, f"Retrieved {len(answers)} answer(s) for question {test_question_id}")
                    if answers:
                        print(f"   Sample answer: {answers[0].get('answer_text', 'N/A')[:50]}...")
                    results.append(True)
                else:
                    print("   No questions found, skipping test")
                    results.append(True)
            else:
                print("   No sessions found, skipping test")
                results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get answers by question: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Get final answer by question (if questions exist)
        print("\n5.2 Testing: Get final answer by question")
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            sessions = client.get_sessions_by_user(test_user_id)
            if sessions and len(sessions) > 0:
                test_session_id = sessions[0]['id']
                questions = client.get_questions_by_session(test_session_id)
                if questions and len(questions) > 0:
                    test_question_id = questions[0]['id']
                    final_answer = client.get_final_answer_by_question(test_question_id)
                    if final_answer:
                        print_result(True, f"Retrieved final answer for question {test_question_id}")
                        print(f"   Score: {final_answer.get('score', 'N/A')}")
                        print(f"   Rating: {final_answer.get('rating', 'N/A')}")
                    else:
                        print_result(True, f"No final answer found for question {test_question_id} (this is OK)")
                    results.append(True)
                else:
                    print("   No questions found, skipping test")
                    results.append(True)
            else:
                print("   No sessions found, skipping test")
                results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get final answer by question: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    return all(results)


def test_statistics_queries(client):
    """Test statistics queries"""
    print_section("Test 6: Statistics Queries")
    
    results = []
    
    try:
        # Test: Get user session stats (if users exist)
        print("\n6.1 Testing: Get user session statistics")
        users = client.get_all_users()
        if users and len(users) > 0:
            test_user_id = users[0]['id']
            stats = client.get_user_session_stats(test_user_id)
            print_result(True, f"Retrieved statistics for user {test_user_id}")
            print(f"   Total sessions: {stats.get('total_sessions', 0)}")
            print(f"   Completed sessions: {stats.get('completed_sessions', 0)}")
            print(f"   Total questions: {stats.get('total_questions', 0)}")
            print(f"   Average score: {stats.get('average_score', 0):.2f}" if stats.get('average_score') else "   Average score: N/A")
            results.append(True)
        else:
            print("   No users found, skipping test")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to get user session stats: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    return all(results)


def test_raw_sql_queries(client):
    """Test raw SQL queries for complex operations"""
    print_section("Test 7: Raw SQL Queries")
    
    results = []
    
    try:
        # Test: Complex join query (users with session count)
        print("\n7.1 Testing: Complex join query - Users with session counts")
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT 
                    u.id,
                    u.username,
                    u.email,
                    COUNT(rs.id) as session_count
                FROM users u
                LEFT JOIN reading_sessions rs ON u.id = rs.user_id
                GROUP BY u.id, u.username, u.email
                ORDER BY session_count DESC
                LIMIT 5
            """)
            rows = cursor.fetchall()
            cursor.close()
            
            print_result(True, f"Retrieved {len(rows)} user(s) with session counts")
            for row in rows[:3]:  # Show first 3
                print(f"   User: {row[1]} ({row[2]}) - Sessions: {row[3]}")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to execute complex join query: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Aggregate query (total statistics)
        print("\n7.2 Testing: Aggregate query - Total statistics")
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT 
                    COUNT(DISTINCT u.id) as total_users,
                    COUNT(DISTINCT rs.id) as total_sessions,
                    COUNT(DISTINCT q.id) as total_questions,
                    COUNT(DISTINCT a.id) as total_answers
                FROM users u
                LEFT JOIN reading_sessions rs ON u.id = rs.user_id
                LEFT JOIN questions q ON rs.id = q.session_id
                LEFT JOIN answers a ON q.id = a.question_id
            """)
            row = cursor.fetchone()
            cursor.close()
            
            if row:
                print_result(True, "Retrieved aggregate statistics")
                print(f"   Total users: {row[0]}")
                print(f"   Total sessions: {row[1]}")
                print(f"   Total questions: {row[2]}")
                print(f"   Total answers: {row[3]}")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to execute aggregate query: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    try:
        # Test: Subquery (users with recent sessions)
        print("\n7.3 Testing: Subquery - Users with recent sessions")
        with client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT 
                    u.id,
                    u.username,
                    (SELECT COUNT(*) 
                     FROM reading_sessions rs 
                     WHERE rs.user_id = u.id 
                     AND rs.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)) as recent_sessions
                FROM users u
                ORDER BY recent_sessions DESC
                LIMIT 5
            """)
            rows = cursor.fetchall()
            cursor.close()
            
            print_result(True, f"Retrieved {len(rows)} user(s) with recent session counts")
            for row in rows[:3]:  # Show first 3
                print(f"   User: {row[1]} - Recent sessions (7 days): {row[2]}")
            results.append(True)
    except Exception as e:
        print_result(False, f"Failed to execute subquery: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    return all(results)


def test_backend_api_queries(backend_url=None):
    """Test database queries through backend HTTP API"""
    print_section("Test 8: Backend API Database Queries")
    
    if not REQUESTS_AVAILABLE:
        print("   ⚠️  'requests' library not available, skipping HTTP API tests")
        print("   Install with: pip install requests")
        return True
    
    # Get backend URL
    if not backend_url:
        # Try to get from environment or detect from Cloud Run
        backend_url = os.environ.get('BACKEND_URL')
        if not backend_url:
            # Try to detect from gcloud
            try:
                import subprocess
                result = subprocess.run(
                    ['gcloud', 'run', 'services', 'describe', 'lunareading-backend',
                     '--region', 'us-central1', '--format', 'value(status.url)'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0 and result.stdout.strip():
                    backend_url = result.stdout.strip()
            except Exception:
                pass
    
    if not backend_url:
        print("   ⚠️  Backend URL not provided, skipping HTTP API tests")
        print("   Set BACKEND_URL environment variable or pass as argument")
        return True
    
    backend_url = backend_url.rstrip('/')
    print(f"   Backend URL: {backend_url}")
    
    results = []
    session = requests.Session()
    
    # Test 8.1: Root endpoint first (to verify backend is accessible)
    try:
        print("\n8.1 Testing: GET / (root endpoint)")
        response = session.get(f"{backend_url}/", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print_result(True, f"Root endpoint working")
            print(f"   Status: {data.get('status', 'N/A')}")
            print(f"   Database Status: {data.get('database_status', 'N/A')}")
            results.append(True)
        else:
            print_result(False, f"Root endpoint returned {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            print(f"   ⚠️  This might not be the backend URL, or backend is not running")
            results.append(False)
    except Exception as e:
        print_result(False, f"Failed to test root endpoint: {str(e)}")
        print(f"   ⚠️  Cannot connect to backend at {backend_url}")
        print(f"   Verify the backend URL is correct")
        traceback.print_exc()
        results.append(False)
    
    # Test 8.2: Database status endpoint
    try:
        print("\n8.2 Testing: GET /api/db-status")
        response = session.get(f"{backend_url}/api/db-status", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print_result(True, f"Database status endpoint working")
            print(f"   Status: {data.get('status', 'N/A')}")
            print(f"   Database: {data.get('database', 'N/A')}")
            results.append(data.get('status') == 'connected')
        elif response.status_code == 404:
            print_result(False, f"Database status endpoint returned 404 (Not Found)")
            print(f"   ⚠️  This endpoint might not be deployed in the backend")
            print(f"   The endpoint exists in code but may not be in the deployed version")
            print(f"   Solution: Redeploy the backend with the latest code")
            print(f"   Response: {response.text[:200]}")
            results.append(False)
        else:
            print_result(False, f"Database status endpoint returned {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            results.append(False)
    except Exception as e:
        print_result(False, f"Failed to test database status: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    # Test 8.3: Register a test user (creates database record)
    test_username = None
    test_token = None
    try:
        print("\n8.3 Testing: POST /api/register (database insert)")
        test_username = f"test_query_{os.getpid()}_{int(time.time())}"
        test_email = f"{test_username}@test.example.com"
        test_password = "TestPassword123!"
        
        response = session.post(
            f"{backend_url}/api/register",
            json={
                'username': test_username,
                'email': test_email,
                'password': test_password,
                'grade_level': 3
            },
            timeout=10
        )
        
        if response.status_code == 201:
            data = response.json()
            print_result(True, f"User registration successful (database insert)")
            print(f"   User ID: {data.get('user_id', 'N/A')}")
            test_token = data.get('access_token')
            results.append(True)
        elif response.status_code == 400:
            # User might already exist, try to login instead
            print("   User may already exist, attempting login...")
            login_response = session.post(
                f"{backend_url}/api/login",
                json={'email': test_email, 'password': test_password},
                timeout=10
            )
            if login_response.status_code == 200:
                login_data = login_response.json()
                test_token = login_data.get('access_token')
                print_result(True, "Login successful (database query)")
                results.append(True)
            else:
                print_result(False, f"Registration and login both failed")
                results.append(False)
        else:
            print_result(False, f"Registration returned {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            results.append(False)
    except Exception as e:
        print_result(False, f"Failed to test registration: {str(e)}")
        traceback.print_exc()
        results.append(False)
    
    # Test 8.4: Get user profile (database query)
    if test_token:
        try:
            print("\n8.4 Testing: GET /api/profile (database query)")
            headers = {'Authorization': f'Bearer {test_token}'}
            response = session.get(f"{backend_url}/api/profile", headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                print_result(True, f"Profile retrieval successful (database query)")
                print(f"   Username: {data.get('username', 'N/A')}")
                print(f"   Email: {data.get('email', 'N/A')}")
                print(f"   Grade Level: {data.get('grade_level', 'N/A')}")
                results.append(True)
            else:
                print_result(False, f"Profile endpoint returned {response.status_code}")
                print(f"   Response: {response.text[:200]}")
                results.append(False)
        except Exception as e:
            print_result(False, f"Failed to test profile: {str(e)}")
            traceback.print_exc()
            results.append(False)
        
        # Test 8.5: Get sessions (database query)
        try:
            print("\n8.5 Testing: GET /api/sessions (database query)")
            headers = {'Authorization': f'Bearer {test_token}'}
            response = session.get(f"{backend_url}/api/sessions", headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                sessions = data if isinstance(data, list) else data.get('sessions', [])
                print_result(True, f"Sessions retrieval successful (database query)")
                print(f"   Total sessions: {len(sessions)}")
                if sessions:
                    print(f"   Sample session: {sessions[0].get('book_title', 'N/A')}")
                results.append(True)
            else:
                print_result(False, f"Sessions endpoint returned {response.status_code}")
                print(f"   Response: {response.text[:200]}")
                results.append(False)
        except Exception as e:
            print_result(False, f"Failed to test sessions: {str(e)}")
            traceback.print_exc()
            results.append(False)
        
        # Test 8.6: Get all users (admin endpoint - database query)
        try:
            print("\n8.6 Testing: GET /api/admin/users (database query)")
            headers = {'Authorization': f'Bearer {test_token}'}
            response = session.get(f"{backend_url}/api/admin/users", headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                users = data.get('users', [])
                print_result(True, f"Admin users endpoint successful (database query)")
                print(f"   Total users: {data.get('total_users', len(users))}")
                if users:
                    print(f"   Sample user: {users[0].get('username', 'N/A')}")
                results.append(True)
            else:
                print_result(False, f"Admin users endpoint returned {response.status_code}")
                print(f"   Response: {response.text[:200]}")
                results.append(False)
        except Exception as e:
            print_result(False, f"Failed to test admin users: {str(e)}")
            traceback.print_exc()
            results.append(False)
    else:
        print("\n8.4-8.6 Skipping: No authentication token available")
        results.extend([True, True, True])  # Skip these tests
    
    return all(results)


def main():
    """Run all database query tests"""
    print("\n" + "=" * 60)
    print("  Database Query Test Suite")
    print("=" * 60)
    print(f"\nDatabase: {Config.CLOUDSQL_DATABASE}")
    print(f"Instance: {Config.CLOUDSQL_INSTANCE_CONNECTION_NAME}")
    print()
    
    # Test connection
    client = test_connection()
    if not client:
        print("\n❌ Cannot proceed without database connection")
        sys.exit(1)
    
    # Run all tests
    test_results = []
    
    test_results.append(("User Queries", test_user_queries(client)))
    test_results.append(("Session Queries", test_session_queries(client)))
    test_results.append(("Question Queries", test_question_queries(client)))
    test_results.append(("Answer Queries", test_answer_queries(client)))
    test_results.append(("Statistics Queries", test_statistics_queries(client)))
    test_results.append(("Raw SQL Queries", test_raw_sql_queries(client)))
    
    # Test backend API queries (optional - requires backend URL)
    # backend_url = sys.argv[1] if len(sys.argv) > 1 else None
    backend_url = "https://lunareading-backend-734731341535.us-central1.run.app"
    test_results.append(("Backend API Queries", test_backend_api_queries(backend_url)))
    
    # Print summary
    print_section("Test Summary")
    passed = sum(1 for _, result in test_results if result)
    total = len(test_results)
    
    for test_name, result in test_results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"  {status}: {test_name}")
    
    print(f"\nTotal: {passed}/{total} test suites passed")
    
    if passed == total:
        print("\n✅ All database query tests passed!")
        sys.exit(0)
    else:
        print(f"\n❌ {total - passed} test suite(s) failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

