#!/usr/bin/env python3
"""Test login with new password"""
import requests
import json

login_url = "http://localhost:5001/api/login"

# Test with old password (should fail)
print("1. Testing with OLD password (should fail)...")
old_login = requests.post(login_url, json={
    "username": "testuser",
    "password": "testpass123"
})
print(f"   Status: {old_login.status_code}")
print(f"   Result: {'❌ Failed (expected)' if old_login.status_code == 401 else '⚠️ Unexpected result'}\n")

# Test with new password (should succeed)
print("2. Testing with NEW password (should succeed)...")
new_login = requests.post(login_url, json={
    "username": "testuser",
    "password": "newpassword123"
})
print(f"   Status: {new_login.status_code}")
if new_login.status_code == 200:
    print("   ✅ Login successful with new password!")
    data = new_login.json()
    print(f"   Username: {data['user']['username']}")
    print(f"   Grade Level: {data['user']['grade_level']}")
else:
    print(f"   ❌ Login failed: {new_login.text}")

