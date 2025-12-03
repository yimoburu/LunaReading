#!/usr/bin/env python3
"""Test script to debug registration endpoint"""
import requests
import json

# Test registration - use backend port directly
url = "http://localhost:5001/api/register"
data = {
    "username": "testuser",
    "email": "test@example.com",
    "password": "testpass123",
    "grade_level": 3
}

print("Testing registration endpoint...")
print(f"URL: {url}")
print(f"Data: {json.dumps(data, indent=2)}")

try:
    response = requests.post(url, json=data)
    print(f"\nStatus Code: {response.status_code}")
    print(f"Response Headers: {dict(response.headers)}")
    print(f"Response Text: {response.text[:500]}")  # First 500 chars
    
    try:
        print(f"\nResponse JSON: {json.dumps(response.json(), indent=2)}")
    except json.JSONDecodeError:
        print("\n⚠️  Response is not valid JSON")
        
except requests.exceptions.ConnectionError:
    print("\n❌ ERROR: Could not connect to server. Is the backend running on port 5001?")
    print("   Start the backend with: cd backend && python app.py")
except Exception as e:
    print(f"\n❌ ERROR: {str(e)}")
    import traceback
    traceback.print_exc()

