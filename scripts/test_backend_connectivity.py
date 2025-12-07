#!/usr/bin/env python3
"""
Test backend server connectivity and diagnose connection issues
"""

import os
import sys
import json
import time
import socket
import ssl
import traceback
from urllib.parse import urlparse
from typing import Dict, Optional

try:
    import requests
    from requests.adapters import HTTPAdapter
    from requests.packages.urllib3.util.retry import Retry
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


def test_dns_resolution(hostname: str) -> Dict:
    """Test DNS resolution"""
    result = {'success': False, 'ip': None, 'error': None}
    try:
        ip = socket.gethostbyname(hostname)
        result['success'] = True
        result['ip'] = ip
    except socket.gaierror as e:
        result['error'] = f"DNS resolution failed: {str(e)}"
    except Exception as e:
        result['error'] = str(e)
    return result


def test_tcp_connection(hostname: str, port: int, timeout: int = 5) -> Dict:
    """Test TCP connection"""
    result = {'success': False, 'error': None}
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        connection_result = sock.connect_ex((hostname, port))
        sock.close()
        
        if connection_result == 0:
            result['success'] = True
        else:
            result['error'] = f"Connection refused or timeout (error code: {connection_result})"
    except socket.timeout:
        result['error'] = "Connection timeout"
    except Exception as e:
        result['error'] = str(e)
    return result


def test_ssl_certificate(hostname: str, port: int = 443) -> Dict:
    """Test SSL certificate"""
    result = {'success': False, 'cert': None, 'error': None}
    try:
        context = ssl.create_default_context()
        with socket.create_connection((hostname, port), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()
                result['success'] = True
                result['cert'] = cert
    except ssl.SSLError as e:
        result['error'] = f"SSL error: {str(e)}"
    except socket.timeout:
        result['error'] = "Connection timeout"
    except Exception as e:
        result['error'] = str(e)
    return result


def test_http_request(url: str, method: str = 'GET', timeout: int = 10, 
                     headers: Optional[Dict] = None, json_data: Optional[Dict] = None) -> Dict:
    """Test HTTP request"""
    result = {
        'success': False,
        'status_code': None,
        'response_time': None,
        'headers': None,
        'data': None,
        'error': None
    }
    
    try:
        session = requests.Session()
        
        # Add retry strategy
        retry_strategy = Retry(
            total=3,
            backoff_factor=0.3,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST", "PUT", "DELETE"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        
        start_time = time.time()
        
        if method.upper() == 'GET':
            response = session.get(url, timeout=timeout, headers=headers)
        elif method.upper() == 'POST':
            response = session.post(url, timeout=timeout, headers=headers, json=json_data)
        else:
            response = session.request(method, url, timeout=timeout, headers=headers, json=json_data)
        
        result['response_time'] = time.time() - start_time
        result['status_code'] = response.status_code
        result['headers'] = dict(response.headers)
        
        # Try to parse JSON
        try:
            result['data'] = response.json()
        except:
            result['data'] = response.text[:500]  # First 500 chars
        
        # Consider 2xx and 3xx as success
        if 200 <= response.status_code < 400:
            result['success'] = True
        else:
            result['error'] = f"HTTP {response.status_code}: {response.text[:200]}"
            
    except requests.exceptions.ConnectionError as e:
        result['error'] = f"Connection error: {str(e)}"
    except requests.exceptions.Timeout:
        result['error'] = f"Request timeout after {timeout}s"
    except requests.exceptions.SSLError as e:
        result['error'] = f"SSL error: {str(e)}"
    except Exception as e:
        result['error'] = str(e)
        traceback.print_exc()
    
    return result


def test_backend_endpoints(base_url: str) -> Dict:
    """Test various backend endpoints"""
    results = {
        'health_check': None,
        'db_status': None,
        'register': None,
        'login': None
    }
    
    base_url = base_url.rstrip('/')
    
    # Test 1: Health check
    print("\n  1. Testing Health Check (GET /)")
    health_result = test_http_request(f"{base_url}/")
    results['health_check'] = health_result
    if health_result['success']:
        print_result(True, f"Health check successful (HTTP {health_result['status_code']})")
        print(f"      Response time: {health_result['response_time']:.2f}s")
        if health_result['data']:
            if isinstance(health_result['data'], dict):
                print(f"      Status: {health_result['data'].get('status', 'N/A')}")
                print(f"      Database: {health_result['data'].get('database_status', 'N/A')}")
    else:
        print_result(False, f"Health check failed: {health_result['error']}")
    
    # Test 2: Database status
    print("\n  2. Testing Database Status (GET /api/db-status)")
    db_result = test_http_request(f"{base_url}/api/db-status")
    results['db_status'] = db_result
    if db_result['success']:
        print_result(True, f"Database status endpoint accessible (HTTP {db_result['status_code']})")
        print(f"      Response time: {db_result['response_time']:.2f}s")
        if db_result['data'] and isinstance(db_result['data'], dict):
            print(f"      Status: {db_result['data'].get('status', 'N/A')}")
    elif db_result['status_code'] == 404:
        print_result(False, f"Endpoint not found (404) - may not be deployed")
    else:
        print_result(False, f"Database status failed: {db_result['error']}")
    
    # Test 3: Register endpoint (just check if it exists)
    print("\n  3. Testing Register Endpoint (POST /api/register)")
    register_result = test_http_request(
        f"{base_url}/api/register",
        method='POST',
        json_data={'username': 'test', 'email': 'test@test.com', 'password': 'test', 'grade_level': 3}
    )
    results['register'] = register_result
    if register_result['status_code'] in [201, 400]:  # 201 = success, 400 = bad request (but endpoint exists)
        print_result(True, f"Register endpoint accessible (HTTP {register_result['status_code']})")
        print(f"      Response time: {register_result['response_time']:.2f}s")
    elif register_result['status_code'] == 404:
        print_result(False, f"Endpoint not found (404)")
    else:
        error_msg = register_result.get('error') or f"HTTP {register_result.get('status_code', 'unknown')}"
        print_result(False, f"Register endpoint test failed: {error_msg}")
    
    # Test 4: Login endpoint (just check if it exists)
    print("\n  4. Testing Login Endpoint (POST /api/login)")
    login_result = test_http_request(
        f"{base_url}/api/login",
        method='POST',
        json_data={'email': 'test@test.com', 'password': 'test'}
    )
    results['login'] = login_result
    if login_result['status_code'] in [200, 401]:  # 200 = success, 401 = unauthorized (but endpoint exists)
        print_result(True, f"Login endpoint accessible (HTTP {login_result['status_code']})")
        print(f"      Response time: {login_result['response_time']:.2f}s")
    elif login_result['status_code'] == 404:
        print_result(False, f"Endpoint not found (404)")
    else:
        error_msg = login_result.get('error') or f"HTTP {login_result.get('status_code', 'unknown')}"
        print_result(False, f"Login endpoint test failed: {error_msg}")
    
    return results


def main():
    """Main test function"""
    print_section("Backend Connectivity Test")
    
    # Get backend URL
    backend_url = sys.argv[1] if len(sys.argv) > 1 else None
    
    if not backend_url:
        # Try to get from environment or auto-detect
        backend_url = os.environ.get('BACKEND_URL')
        if not backend_url:
            print("  Auto-detecting backend URL...")
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
                    print(f"  ✅ Found backend: {backend_url}")
            except Exception as e:
                print(f"  ⚠️  Could not auto-detect: {e}")
    
    if not backend_url:
        print("  ❌ Backend URL not provided")
        print("  Usage: python3 test_backend_connectivity.py <backend-url>")
        print("  Or set BACKEND_URL environment variable")
        sys.exit(1)
    
    print(f"\n  Backend URL: {backend_url}")
    
    # Parse URL
    parsed = urlparse(backend_url)
    hostname = parsed.hostname
    port = parsed.port or (443 if parsed.scheme == 'https' else 80)
    scheme = parsed.scheme
    
    print(f"  Hostname: {hostname}")
    print(f"  Port: {port}")
    print(f"  Scheme: {scheme}")
    
    # Test 1: DNS Resolution
    print_section("Test 1: DNS Resolution")
    dns_result = test_dns_resolution(hostname)
    if dns_result['success']:
        print_result(True, f"DNS resolution successful: {hostname} -> {dns_result['ip']}")
    else:
        print_result(False, f"DNS resolution failed: {dns_result['error']}")
        print("\n  💡 Possible causes:")
        print("     - Backend service doesn't exist")
        print("     - Network connectivity issues")
        print("     - DNS server problems")
        sys.exit(1)
    
    # Test 2: TCP Connection
    print_section("Test 2: TCP Connection")
    tcp_result = test_tcp_connection(hostname, port)
    if tcp_result['success']:
        print_result(True, f"TCP connection successful on port {port}")
    else:
        print_result(False, f"TCP connection failed: {tcp_result['error']}")
        print("\n  💡 Possible causes:")
        print("     - Backend service is down")
        print("     - Firewall blocking connection")
        print("     - Wrong port number")
        print("     - Service not deployed")
    
    # Test 3: SSL Certificate (if HTTPS)
    if scheme == 'https':
        print_section("Test 3: SSL Certificate")
        ssl_result = test_ssl_certificate(hostname, port)
        if ssl_result['success']:
            print_result(True, f"SSL certificate valid")
            if ssl_result['cert']:
                subject = dict(x[0] for x in ssl_result['cert']['subject'])
                print(f"      Subject: {subject.get('commonName', 'N/A')}")
        else:
            print_result(False, f"SSL certificate check failed: {ssl_result['error']}")
    
    # Test 4: HTTP Endpoints
    print_section("Test 4: HTTP Endpoints")
    endpoint_results = test_backend_endpoints(backend_url)
    
    # Summary
    print_section("Test Summary")
    
    print(f"  Backend URL: {backend_url}")
    print(f"  DNS Resolution: {'✅' if dns_result['success'] else '❌'}")
    print(f"  TCP Connection: {'✅' if tcp_result['success'] else '❌'}")
    if scheme == 'https':
        print(f"  SSL Certificate: {'✅' if ssl_result['success'] else '❌'}")
    print(f"  Health Check: {'✅' if endpoint_results['health_check'] and endpoint_results['health_check']['success'] else '❌'}")
    print(f"  DB Status: {'✅' if endpoint_results['db_status'] and endpoint_results['db_status']['success'] else '❌'}")
    print(f"  Register: {'✅' if endpoint_results['register'] and endpoint_results['register']['status_code'] in [201, 400] else '❌'}")
    print(f"  Login: {'✅' if endpoint_results['login'] and endpoint_results['login']['status_code'] in [200, 401] else '❌'}")
    
    # Overall status
    all_tests_passed = (
        dns_result['success'] and
        tcp_result['success'] and
        (ssl_result['success'] if scheme == 'https' else True) and
        endpoint_results['health_check'] and endpoint_results['health_check']['success']
    )
    
    if all_tests_passed:
        print("\n  ✅ Backend is accessible and responding!")
    else:
        print("\n  ❌ Backend connectivity issues detected")
        print("\n  💡 Troubleshooting steps:")
        print("     1. Check if backend service is deployed:")
        print("        gcloud run services list --region us-central1")
        print("     2. Check backend service status:")
        print(f"        gcloud run services describe lunareading-backend --region us-central1")
        print("     3. Check backend logs:")
        print(f"        gcloud run services logs read lunareading-backend --region us-central1 --limit 50")
        print("     4. Verify backend URL is correct")
        print("     5. Check network connectivity and firewall rules")
    
    sys.exit(0 if all_tests_passed else 1)


if __name__ == "__main__":
    main()

