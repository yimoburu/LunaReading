#!/usr/bin/env python3
"""
Test database operations through the backend API
Tests the full stack: HTTP -> Flask -> Database

Requirements:
    pip install requests
"""

import os
import sys
import json
import time
import traceback
from typing import Optional, Dict, Any

try:
    import requests
except ImportError:
    print("❌ Error: 'requests' library is required")
    print("   Install it with: pip install requests")
    sys.exit(1)


def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)


def print_result(success, message):
    """Print a formatted result"""
    status = "✅" if success else "❌"
    print(f"{status} {message}")


def print_response(response: requests.Response, show_body=True):
    """Print HTTP response details"""
    print(f"  Status Code: {response.status_code}")
    if show_body:
        try:
            body = response.json()
            print(f"  Response: {json.dumps(body, indent=2)}")
        except:
            print(f"  Response: {response.text[:200]}")


class BackendTester:
    """Test backend API endpoints"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        self.test_user_token: Optional[str] = None
        self.test_user_id: Optional[int] = None
        self.test_username: Optional[str] = None
    
    def test_health_check(self) -> bool:
        """Test backend health check endpoint"""
        print_section("Test 1: Backend Health Check")
        
        try:
            response = self.session.get(f"{self.base_url}/")
            print_response(response)
            
            if response.status_code == 200:
                data = response.json()
                print_result(True, "Backend is running")
                print(f"  Message: {data.get('message', 'N/A')}")
                print(f"  Database Status: {data.get('database_status', 'N/A')}")
                return True
            else:
                print_result(False, f"Backend returned status {response.status_code}")
                return False
        except requests.exceptions.ConnectionError:
            print_result(False, "Cannot connect to backend")
            print(f"  URL: {self.base_url}")
            print("  Make sure the backend is running")
            return False
        except Exception as e:
            print_result(False, f"Health check failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def test_db_status(self) -> bool:
        """Test database status endpoint"""
        print_section("Test 2: Database Status Check")
        
        try:
            response = self.session.get(f"{self.base_url}/api/db-status")
            print_response(response)
            
            if response.status_code == 200:
                data = response.json()
                print_result(True, "Database connection is working")
                print(f"  Instance: {data.get('instance', 'N/A')}")
                print(f"  Database: {data.get('database', 'N/A')}")
                return True
            elif response.status_code == 500:
                data = response.json()
                print_result(False, "Database connection failed")
                print(f"  Error: {data.get('message', 'N/A')}")
                return False
            else:
                print_result(False, f"Unexpected status code: {response.status_code}")
                return False
        except Exception as e:
            print_result(False, f"Database status check failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def test_registration(self) -> bool:
        """Test user registration endpoint"""
        print_section("Test 3: User Registration")
        
        try:
            # Generate unique test user
            timestamp = int(time.time())
            self.test_username = f"test_user_{timestamp}_{os.getpid()}"
            test_email = f"{self.test_username}@test.example.com"
            test_password = "testpass123"
            test_grade = 3
            
            payload = {
                "username": self.test_username,
                "email": test_email,
                "password": test_password,
                "grade_level": test_grade
            }
            
            print(f"  Registering user: {self.test_username}")
            response = self.session.post(
                f"{self.base_url}/api/register",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            print_response(response)
            
            if response.status_code == 201:
                data = response.json()
                self.test_user_token = data.get('access_token')
                user_data = data.get('user', {})
                self.test_user_id = user_data.get('id')
                
                print_result(True, "User registered successfully")
                print(f"  User ID: {self.test_user_id}")
                print(f"  Username: {user_data.get('username')}")
                print(f"  Email: {user_data.get('email')}")
                print(f"  Grade Level: {user_data.get('grade_level')}")
                print(f"  Token received: {'Yes' if self.test_user_token else 'No'}")
                return True
            elif response.status_code == 400:
                data = response.json()
                error = data.get('error', 'Unknown error')
                print_result(False, f"Registration failed: {error}")
                if 'already exists' in error.lower():
                    print("  User may already exist - this is expected if test was run before")
                    return True  # Not a database issue
                return False
            elif response.status_code == 500:
                data = response.json()
                error = data.get('error', 'Unknown error')
                print_result(False, f"Server error during registration: {error}")
                return False
            else:
                print_result(False, f"Unexpected status code: {response.status_code}")
                return False
        except Exception as e:
            print_result(False, f"Registration test failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def test_duplicate_registration(self) -> bool:
        """Test that duplicate registration is rejected"""
        print_section("Test 4: Duplicate Registration Prevention")
        
        if not self.test_username:
            print("  ⚠️  Skipping - no test user created")
            return False
        
        try:
            payload = {
                "username": self.test_username,
                "email": f"different_{self.test_username}@test.example.com",
                "password": "differentpass",
                "grade_level": 4
            }
            
            print(f"  Attempting duplicate registration: {self.test_username}")
            response = self.session.post(
                f"{self.base_url}/api/register",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            print_response(response)
            
            if response.status_code == 400:
                data = response.json()
                error = data.get('error', '')
                if 'already exists' in error.lower():
                    print_result(True, "Duplicate registration correctly rejected")
                    return True
                else:
                    print_result(False, f"Unexpected error: {error}")
                    return False
            else:
                print_result(False, f"Duplicate registration should be rejected (got {response.status_code})")
                return False
        except Exception as e:
            print_result(False, f"Duplicate registration test failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def test_login(self) -> bool:
        """Test user login endpoint"""
        print_section("Test 5: User Login")
        
        if not self.test_username:
            print("  ⚠️  Skipping - no test user created")
            return False
        
        try:
            payload = {
                "username": self.test_username,
                "password": "testpass123"
            }
            
            print(f"  Logging in user: {self.test_username}")
            response = self.session.post(
                f"{self.base_url}/api/login",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            print_response(response)
            
            if response.status_code == 200:
                data = response.json()
                token = data.get('access_token')
                user_data = data.get('user', {})
                
                print_result(True, "Login successful")
                print(f"  User ID: {user_data.get('id')}")
                print(f"  Username: {user_data.get('username')}")
                print(f"  Token received: {'Yes' if token else 'No'}")
                return True
            elif response.status_code == 401:
                data = response.json()
                error = data.get('error', 'Unknown error')
                print_result(False, f"Login failed: {error}")
                return False
            else:
                print_result(False, f"Unexpected status code: {response.status_code}")
                return False
        except Exception as e:
            print_result(False, f"Login test failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def test_get_profile(self) -> bool:
        """Test getting user profile (requires authentication)"""
        print_section("Test 6: Get User Profile")
        
        if not self.test_user_token:
            print("  ⚠️  Skipping - no authentication token")
            return False
        
        try:
            headers = {
                "Authorization": f"Bearer {self.test_user_token}",
                "Content-Type": "application/json"
            }
            
            print("  Fetching user profile...")
            response = self.session.get(
                f"{self.base_url}/api/profile",
                headers=headers
            )
            
            print_response(response)
            
            if response.status_code == 200:
                data = response.json()
                print_result(True, "Profile retrieved successfully")
                print(f"  User ID: {data.get('id')}")
                print(f"  Username: {data.get('username')}")
                print(f"  Email: {data.get('email')}")
                print(f"  Grade Level: {data.get('grade_level')}")
                print(f"  Reading Level: {data.get('reading_level')}")
                return True
            elif response.status_code == 401:
                print_result(False, "Authentication failed")
                return False
            else:
                print_result(False, f"Unexpected status code: {response.status_code}")
                return False
        except Exception as e:
            print_result(False, f"Get profile test failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def test_update_profile(self) -> bool:
        """Test updating user profile"""
        print_section("Test 7: Update User Profile")
        
        if not self.test_user_token:
            print("  ⚠️  Skipping - no authentication token")
            return False
        
        try:
            headers = {
                "Authorization": f"Bearer {self.test_user_token}",
                "Content-Type": "application/json"
            }
            
            # Update grade level
            new_grade = 4
            payload = {
                "grade_level": new_grade
            }
            
            print(f"  Updating profile (grade_level to {new_grade})...")
            response = self.session.put(
                f"{self.base_url}/api/profile",
                json=payload,
                headers=headers
            )
            
            print_response(response)
            
            if response.status_code == 200:
                data = response.json()
                print_result(True, "Profile updated successfully")
                print(f"  Updated Grade Level: {data.get('grade_level')}")
                
                # Verify the update
                if data.get('grade_level') == new_grade:
                    print_result(True, "Update verified in response")
                    return True
                else:
                    print_result(False, "Update not reflected in response")
                    return False
            else:
                print_result(False, f"Update failed with status {response.status_code}")
                return False
        except Exception as e:
            print_result(False, f"Update profile test failed: {str(e)}")
            traceback.print_exc()
            return False
    
    def cleanup_test_user(self):
        """Clean up test user (if admin endpoint exists)"""
        if not self.test_username:
            return
        
        print_section("Cleanup: Test User")
        print(f"  Test user created: {self.test_username}")
        print("  Note: Test user may remain in database")
        print("  You can manually delete it if needed")


def main():
    """Run all backend tests"""
    print("\n" + "=" * 60)
    print("  Database Test Through Backend API")
    print("=" * 60)
    print("\nThis script tests database operations through the Flask backend API.\n")
    
    # Get backend URL
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        # Try to get backend URL from gcloud, fallback to local
        import subprocess
        try:
            result = subprocess.run(
                ['gcloud', 'run', 'services', 'describe', 'lunareading-backend',
                 '--region', 'us-central1', '--format', 'value(status.url)'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                base_url = result.stdout.strip()
                print(f"📡 Auto-detected backend URL: {base_url}")
            else:
                base_url = os.getenv('BACKEND_URL', 'http://localhost:5001')
        except:
            base_url = os.getenv('BACKEND_URL', 'http://localhost:5001')
    
    print(f"Backend URL: {base_url}\n")
    
    # Create tester
    tester = BackendTester(base_url)
    
    # Run tests
    results = {}
    
    results['health_check'] = tester.test_health_check()
    if not results['health_check']:
        print("\n❌ Backend is not accessible. Cannot continue.")
        print("\n💡 Troubleshooting:")
        print("  1. Make sure the backend is running")
        print("  2. Check the backend URL is correct")
        print("  3. For Cloud Run: use the full HTTPS URL")
        sys.exit(1)
    
    results['db_status'] = tester.test_db_status()
    results['registration'] = tester.test_registration()
    results['duplicate_registration'] = tester.test_duplicate_registration()
    results['login'] = tester.test_login()
    results['get_profile'] = tester.test_get_profile()
    results['update_profile'] = tester.test_update_profile()
    
    # Cleanup
    tester.cleanup_test_user()
    
    # Summary
    print_section("Test Summary")
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}: {test_name}")
    
    print(f"\nResults: {passed}/{total} tests passed")
    
    if passed == total:
        print_result(True, "All tests passed! Database operations through backend are working correctly.")
        return 0
    else:
        print_result(False, f"{total - passed} test(s) failed. Check errors above.")
        print("\n💡 Troubleshooting:")
        print("  1. Check backend logs for detailed error messages")
        print("  2. Verify database connection is working (run test_database_direct.py)")
        print("  3. Check that Cloud SQL instance is added to Cloud Run service")
        print("  4. Verify environment variables are set correctly")
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

