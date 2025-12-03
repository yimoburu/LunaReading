# Testing Backend API Directly

## Quick Test Scripts

### Test Registration (Interactive)
```bash
./test_register_direct.sh us-central1
```
This will prompt for username, email, password, and grade level, then test the registration endpoint.

### Test Registration (Quick - Auto-generated Data)
```bash
./test_register_quick.sh us-central1
```
This automatically generates test data and registers a new user. Useful for quick testing.

### Test Login Only
```bash
./test_login_direct.sh us-central1
```
This will prompt for username and password, then test the login endpoint.

### Test All Endpoints
```bash
./test_backend_api.sh us-central1
```
This will test:
- Health check
- Registration
- Login
- Profile (if login succeeds)

## Manual Testing with curl

### 1. Get Backend URL
```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')
echo $BACKEND_URL
```

### 2. Test Health Check
```bash
curl $BACKEND_URL/
```

### 3. Test Registration
```bash
# Basic registration
curl -X POST $BACKEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "test123",
    "grade_level": 3
  }'

# Pretty print response
curl -X POST $BACKEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "test123",
    "grade_level": 3
  }' | python3 -m json.tool

# With unique timestamp to avoid conflicts
TIMESTAMP=$(date +%s)
curl -X POST $BACKEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"testuser${TIMESTAMP}\",
    \"email\": \"test${TIMESTAMP}@example.com\",
    \"password\": \"test123\",
    \"grade_level\": 3
  }" | python3 -m json.tool
```

### 4. Test Login
```bash
curl -X POST $BACKEND_URL/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123"
  }'
```

### 5. Test Profile (with token from login)
```bash
# First, get token from login response, then:
TOKEN="your-access-token-here"

curl -X GET $BACKEND_URL/api/profile \
  -H "Authorization: Bearer $TOKEN"
```

### 6. Test Create Session
```bash
TOKEN="your-access-token-here"

curl -X POST $BACKEND_URL/api/sessions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "book_title": "The Cat in the Hat",
    "chapter": "Chapter 1"
  }'
```

## Using Python

```python
import requests
import json

BACKEND_URL = "https://your-backend-url.run.app"

# Login
response = requests.post(
    f"{BACKEND_URL}/api/login",
    json={"username": "testuser", "password": "test123"}
)
print(f"Status: {response.status_code}")
print(f"Response: {response.json()}")

# Get token
token = response.json().get("access_token")

# Get profile
headers = {"Authorization": f"Bearer {token}"}
profile = requests.get(f"{BACKEND_URL}/api/profile", headers=headers)
print(f"Profile: {profile.json()}")
```

## Common Issues

### 502 Bad Gateway
- Backend might not be running
- Check: `gcloud run services logs read lunareading-backend --region us-central1`

### 401 Unauthorized
- Invalid token
- Token expired
- Missing Authorization header

### 400 Bad Request
- Missing required fields
- Invalid JSON format
- Check request body

### 500 Internal Server Error
- Backend error
- Check logs: `gcloud run services logs read lunareading-backend --region us-central1 --limit 50`

