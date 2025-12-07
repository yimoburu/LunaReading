#!/usr/bin/env python3
"""
Compare register and login functionalities between local and cloud backend servers
Tests both environments and compares results
"""

import os
import sys
import json
import time
import traceback
from typing import Dict, Optional, Tuple
from pathlib import Path

try:
    import requests
except ImportError:
    print("❌ Error: 'requests' library is required")
    print("   Install it with: pip install requests")
    sys.exit(1)


def print_section(title):
    """Print a formatted section header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)


def print_result(success, message, indent=0):
    """Print a formatted result"""
    status = "✅" if success else "❌"
    indent_str = "  " * indent
    print(f"{indent_str}{status} {message}")


def print_comparison(local_result, cloud_result, test_name):
    """Print comparison between local and cloud results"""
    print(f"\n  📊 Comparison: {test_name}")
    print(f"     Local:  {'✅ PASS' if local_result['success'] else '❌ FAIL'}")
    print(f"     Cloud:  {'✅ PASS' if cloud_result['success'] else '❌ FAIL'}")
    
    if local_result['success'] and cloud_result['success']:
        print(f"     Status: ✅ Both environments working")
    elif not local_result['success'] and not cloud_result['success']:
        print(f"     Status: ❌ Both environments failing")
    else:
        print(f"     Status: ⚠️  Environments differ")
    
    if local_result.get('error'):
        print(f"     Local Error:  {local_result['error']}")
    if cloud_result.get('error'):
        print(f"     Cloud Error:  {cloud_result['error']}")


class BackendTester:
    """Test backend API endpoints"""
    
    def __init__(self, base_url: str, name: str):
        self.base_url = base_url.rstrip('/')
        self.name = name
        self.session = requests.Session()
        self.test_username = None
        self.test_email = None
        self.test_password = "TestPassword123!"
    
    def generate_test_user(self):
        """Generate unique test user credentials"""
        timestamp = int(time.time())
        pid = os.getpid()
        self.test_username = f"test_compare_{pid}_{timestamp}"
        self.test_email = f"{self.test_username}@test.example.com"
        return self.test_username, self.test_email
    
    def test_health_check(self) -> Dict:
        """Test backend health check endpoint"""
        result = {'success': False, 'response': None, 'error': None}
        try:
            response = self.session.get(f"{self.base_url}/", timeout=10)
            result['response'] = response
            if response.status_code == 200:
                result['success'] = True
                result['data'] = response.json()
            else:
                result['error'] = f"HTTP {response.status_code}: {response.text[:200]}"
        except requests.exceptions.ConnectionError:
            result['error'] = f"Cannot connect to {self.base_url}"
        except Exception as e:
            result['error'] = str(e)
        return result
    
    def test_register(self, username: str, email: str, password: str, grade_level: int = 3) -> Dict:
        """Test user registration"""
        result = {'success': False, 'response': None, 'error': None, 'data': None}
        try:
            response = self.session.post(
                f"{self.base_url}/api/register",
                json={
                    'username': username,
                    'email': email,
                    'password': password,
                    'grade_level': grade_level
                },
                timeout=10
            )
            result['response'] = response
            
            if response.status_code == 201:
                result['success'] = True
                result['data'] = response.json()
            elif response.status_code == 400:
                # User might already exist
                error_data = response.json() if response.headers.get('content-type', '').startswith('application/json') else {}
                error_msg = error_data.get('error', response.text[:200])
                if 'already exists' in error_msg.lower() or 'already registered' in error_msg.lower():
                    result['error'] = f"User already exists: {error_msg}"
                else:
                    result['error'] = f"Bad request: {error_msg}"
            else:
                result['error'] = f"HTTP {response.status_code}: {response.text[:200]}"
        except requests.exceptions.ConnectionError:
            result['error'] = f"Cannot connect to {self.base_url}"
        except Exception as e:
            result['error'] = str(e)
            traceback.print_exc()
        return result
    
    def test_login(self, user_id: str, password: str) -> Dict:
        """Test user login"""
        result = {'success': False, 'response': None, 'error': None, 'data': None, 'token': None}
        try:
            response = self.session.post(
                f"{self.base_url}/api/login",
                json={
                    'user_id': user_id,
                    'password': password
                },
                timeout=10
            )
            result['response'] = response
            
            if response.status_code == 200:
                result['success'] = True
                result['data'] = response.json()
                result['token'] = result['data'].get('access_token')
            elif response.status_code == 401:
                result['error'] = "Invalid credentials"
            else:
                result['error'] = f"HTTP {response.status_code}: {response.text[:200]}"
        except requests.exceptions.ConnectionError:
            result['error'] = f"Cannot connect to {self.base_url}"
        except Exception as e:
            result['error'] = str(e)
            traceback.print_exc()
        return result
    
    def test_profile(self, token: str) -> Dict:
        """Test getting user profile with token"""
        result = {'success': False, 'response': None, 'error': None, 'data': None}
        try:
            headers = {'Authorization': f'Bearer {token}'}
            response = self.session.get(
                f"{self.base_url}/api/profile",
                headers=headers,
                timeout=10
            )
            result['response'] = response
            
            if response.status_code == 200:
                result['success'] = True
                result['data'] = response.json()
            else:
                result['error'] = f"HTTP {response.status_code}: {response.text[:200]}"
        except Exception as e:
            result['error'] = str(e)
        return result


def test_backend_register_login(tester: BackendTester) -> Dict:
    """Test complete register and login flow for a backend"""
    results = {
        'name': tester.name,
        'url': tester.base_url,
        'health_check': None,
        'register': None,
        'login': None,
        'profile': None,
        'overall_success': False
    }
    
    print(f"\n  Testing: {tester.name}")
    print(f"  URL: {tester.base_url}")
    
    # Test 1: Health check
    print(f"\n  1. Health Check")
    health_result = tester.test_health_check()
    results['health_check'] = health_result
    if health_result['success']:
        print_result(True, f"Backend is running")
        print(f"      Status: {health_result['data'].get('status', 'N/A')}")
        print(f"      Database: {health_result['data'].get('database_status', 'N/A')}")
    else:
        print_result(False, f"Health check failed: {health_result['error']}")
        return results  # Can't proceed if backend is down
    
    # Generate test user
    username, email = tester.generate_test_user()
    print(f"\n  2. Registration")
    print(f"      Username: {username}")
    print(f"      Email: {email}")
    
    # Test 2: Registration
    register_result = tester.test_register(username, email, tester.test_password)
    results['register'] = register_result
    
    if register_result['success']:
        print_result(True, f"Registration successful")
        user_id = register_result['data'].get('user_id')
        token = register_result['data'].get('access_token')
        print(f"      User ID: {user_id}")
        print(f"      Token received: {'Yes' if token else 'No'}")
    else:
        print_result(False, f"Registration failed: {register_result['error']}")
        # Try login in case user already exists
        print(f"      Attempting login with same credentials...")
        login_result = tester.test_login(user_id, tester.test_password)
        if login_result['success']:
            print_result(True, f"Login successful (user already existed)")
            results['login'] = login_result
            results['register'] = {'success': False, 'error': 'User already exists, but login works'}
        else:
            print_result(False, f"Login also failed: {login_result.get('error', 'Unknown error')}")
            return results
    
    # Test 3: Login (if registration provided token, test with fresh login)
    print(f"\n  3. Login")
    login_result = tester.test_login(user_id, tester.test_password)
    results['login'] = login_result
    
    if login_result['success']:
        print_result(True, f"Login successful")
        token = login_result['token']
        print(f"      Token received: {'Yes' if token else 'No'}")
        
        # Test 4: Profile (verify token works)
        if token:
            print(f"\n  4. Profile (Token Verification)")
            profile_result = tester.test_profile(token)
            results['profile'] = profile_result
            
            if profile_result['success']:
                print_result(True, f"Profile retrieval successful")
                profile_data = profile_result['data']
                print(f"      Username: {profile_data.get('username', 'N/A')}")
                print(f"      Email: {profile_data.get('email', 'N/A')}")
                print(f"      Grade Level: {profile_data.get('grade_level', 'N/A')}")
            else:
                print_result(False, f"Profile retrieval failed: {profile_result['error']}")
    else:
        print_result(False, f"Login failed: {login_result['error']}")
    
    # Determine overall success
    results['overall_success'] = (
        health_result['success'] and
        (register_result['success'] or results.get('login', {}).get('success', False)) and
        login_result['success'] and
        (results.get('profile', {}).get('success', False) if login_result.get('token') else True)
    )
    
    return results


def main():
    """Main comparison test"""
    print_section("Backend Comparison Test: Local vs Cloud")
    
    # Get backend URLs
    local_url = os.environ.get('LOCAL_BACKEND_URL', 'http://localhost:5001')
    cloud_url = os.environ.get('CLOUD_BACKEND_URL')
    
    # Try to auto-detect cloud URL
    if not cloud_url:
        print("  Auto-detecting cloud backend URL...")
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
                cloud_url = result.stdout.strip()
                print(f"  ✅ Found cloud backend: {cloud_url}")
        except Exception as e:
            print(f"  ⚠️  Could not auto-detect cloud URL: {e}")
    
    if not cloud_url:
        print("  ❌ Cloud backend URL not provided")
        print("  Set CLOUD_BACKEND_URL environment variable or ensure gcloud is configured")
        sys.exit(1)
    
    print(f"\n  Local Backend:  {local_url}")
    print(f"  Cloud Backend:  {cloud_url}")
    
    # Create testers
    local_tester = BackendTester(local_url, "Local Backend")
    cloud_tester = BackendTester(cloud_url, "Cloud Backend")
    
    # Test both backends
    print_section("Testing Local Backend")
    local_results = test_backend_register_login(local_tester)
    
    print_section("Testing Cloud Backend")
    cloud_results = test_backend_register_login(cloud_tester)
    
    # Compare results
    print_section("Comparison Results")
    
    # Health check comparison
    print_comparison(
        {'success': local_results['health_check']['success'], 'error': local_results['health_check'].get('error')},
        {'success': cloud_results['health_check']['success'], 'error': cloud_results['health_check'].get('error')},
        "Health Check"
    )
    
    # Registration comparison
    local_register_success = local_results['register']['success'] if local_results['register'] else False
    cloud_register_success = cloud_results['register']['success'] if cloud_results['register'] else False
    print_comparison(
        {'success': local_register_success, 'error': local_results['register'].get('error') if local_results['register'] else None},
        {'success': cloud_register_success, 'error': cloud_results['register'].get('error') if cloud_results['register'] else None},
        "Registration"
    )
    
    # Login comparison
    local_login_success = local_results['login']['success'] if local_results['login'] else False
    cloud_login_success = cloud_results['login']['success'] if cloud_results['login'] else False
    print_comparison(
        {'success': local_login_success, 'error': local_results['login'].get('error') if local_results['login'] else None},
        {'success': cloud_login_success, 'error': cloud_results['login'].get('error') if cloud_results['login'] else None},
        "Login"
    )
    
    # Profile comparison
    local_profile_success = local_results['profile']['success'] if local_results.get('profile') else False
    cloud_profile_success = cloud_results['profile']['success'] if cloud_results.get('profile') else False
    print_comparison(
        {'success': local_profile_success, 'error': local_results['profile'].get('error') if local_results.get('profile') else None},
        {'success': cloud_profile_success, 'error': cloud_results['profile'].get('error') if cloud_results.get('profile') else None},
        "Profile (Token Verification)"
    )
    
    # Overall comparison
    print(f"\n  📊 Overall Status:")
    print(f"     Local:  {'✅ PASS' if local_results['overall_success'] else '❌ FAIL'}")
    print(f"     Cloud:  {'✅ PASS' if cloud_results['overall_success'] else '❌ FAIL'}")
    
    if local_results['overall_success'] and cloud_results['overall_success']:
        print(f"\n  ✅ Both environments are working correctly!")
    elif not local_results['overall_success'] and not cloud_results['overall_success']:
        print(f"\n  ❌ Both environments are failing")
    else:
        print(f"\n  ⚠️  Environments differ - one is working, one is not")
    
    # Detailed differences
    print_section("Detailed Differences")
    
    differences = []
    
    # Check response times
    if local_results['health_check']['success'] and cloud_results['health_check']['success']:
        print(f"\n  Response Times:")
        # Note: We don't track response times in current implementation, but could add it
    
    # Check response data structure
    if local_results['register']['success'] and cloud_results['register']['success']:
        local_data = local_results['register']['data']
        cloud_data = cloud_results['register']['data']
        
        local_keys = set(local_data.keys()) if local_data else set()
        cloud_keys = set(cloud_data.keys()) if cloud_data else set()
        
        if local_keys != cloud_keys:
            differences.append(f"Registration response keys differ: Local={local_keys}, Cloud={cloud_keys}")
        else:
            print(f"  ✅ Registration response structure matches")
    
    if local_results['login']['success'] and cloud_results['login']['success']:
        local_data = local_results['login']['data']
        cloud_data = cloud_results['login']['data']
        
        local_keys = set(local_data.keys()) if local_data else set()
        cloud_keys = set(cloud_data.keys()) if cloud_data else set()
        
        if local_keys != cloud_keys:
            differences.append(f"Login response keys differ: Local={local_keys}, Cloud={cloud_keys}")
        else:
            print(f"  ✅ Login response structure matches")
    
    if differences:
        print(f"\n  ⚠️  Differences found:")
        for diff in differences:
            print(f"     - {diff}")
    else:
        print(f"\n  ✅ No structural differences found")
    
    # Summary
    print_section("Test Summary")
    print(f"  Local Backend:  {local_url}")
    print(f"    Status: {'✅ Working' if local_results['overall_success'] else '❌ Failing'}")
    print(f"    Health: {'✅' if local_results['health_check']['success'] else '❌'}")
    print(f"    Register: {'✅' if local_register_success else '❌'}")
    print(f"    Login: {'✅' if local_login_success else '❌'}")
    print(f"    Profile: {'✅' if local_profile_success else '❌'}")
    
    print(f"\n  Cloud Backend:  {cloud_url}")
    print(f"    Status: {'✅ Working' if cloud_results['overall_success'] else '❌ Failing'}")
    print(f"    Health: {'✅' if cloud_results['health_check']['success'] else '❌'}")
    print(f"    Register: {'✅' if cloud_register_success else '❌'}")
    print(f"    Login: {'✅' if cloud_login_success else '❌'}")
    print(f"    Profile: {'✅' if cloud_profile_success else '❌'}")
    
    # Exit code
    if local_results['overall_success'] and cloud_results['overall_success']:
        print(f"\n✅ All tests passed for both environments!")
        sys.exit(0)
    else:
        print(f"\n❌ Some tests failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

