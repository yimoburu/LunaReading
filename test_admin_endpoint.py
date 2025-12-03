#!/usr/bin/env python3
"""Test the admin users endpoint"""
import requests
import json
import sys

# First, login to get a token
login_url = "http://localhost:5001/api/login"
login_data = {
    "username": "testuser",
    "password": "testpass123"
}

print("1. Logging in...")
try:
    login_response = requests.post(login_url, json=login_data)
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.status_code}")
        print(login_response.text)
        sys.exit(1)
    
    token = login_response.json()['access_token']
    print("✅ Login successful\n")
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)

# Now get all users
admin_url = "http://localhost:5001/api/admin/users"
headers = {
    "Authorization": f"Bearer {token}"
}

print("2. Fetching all users...")
try:
    response = requests.get(admin_url, headers=headers)
    print(f"Status Code: {response.status_code}\n")
    
    if response.status_code == 200:
        data = response.json()
        print(f"📊 Total Users: {data['total_users']}\n")
        
        for user in data['users']:
            print(f"User ID: {user['id']}")
            print(f"  Username: {user['username']}")
            print(f"  Email: {user['email']}")
            print(f"  Password Hash: {user['password_hash']}")
            print(f"  Grade Level: {user['grade_level']}")
            print(f"  Reading Level: {user['reading_level']}")
            print(f"  Created: {user['created_at']}")
            stats = user['statistics']
            print(f"  Statistics:")
            print(f"    - Total Sessions: {stats['total_sessions']}")
            print(f"    - Completed Sessions: {stats['completed_sessions']}")
            print(f"    - Total Questions: {stats['total_questions']}")
            print(f"    - Average Score: {stats['average_score']}%" if stats['average_score'] else "    - Average Score: N/A")
            print()
    else:
        print(f"❌ Error: {response.text}")
except Exception as e:
    print(f"❌ Error: {e}")

