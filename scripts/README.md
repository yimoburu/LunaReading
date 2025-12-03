# Scripts

This folder contains debugging, testing, and utility scripts.

## Testing Scripts

- **test_*.py** - Python test scripts for API endpoints
- **test_*.sh** - Shell test scripts
- **test_openai_connection.py** - Test OpenAI API connection
- **test_registration.py** - Test user registration
- **test_login.py** - Test user login
- **test_backend_api.sh** - Test multiple backend endpoints

## Debugging Scripts

- **debug_*.sh** - Frontend/backend debugging scripts
- **check_*.py** - Python diagnostic scripts
- **check_*.sh** - Shell diagnostic scripts
- **check_api_key.py** - Check OpenAI API key configuration
- **check_users.py** - List registered users
- **verify_*.sh** - Verification scripts

## Fix Scripts

- **fix_*.sh** - Scripts to fix specific issues
- **fix_502_error.sh** - Fix 502 Bad Gateway errors
- **fix_504_timeout.sh** - Fix 504 timeout errors
- **fix_container_startup.sh** - Fix container startup issues
- **fix_database.sh** - Fix database issues
- **comprehensive_fix_502.sh** - Comprehensive 502 fix

## Utility Scripts

- **migrate_database.py** - Database migration script
- **reset_password.py** - Reset user password
- **test_admin_endpoint.py** - Test admin endpoints
- **check_users.py** - Check registered users

## Usage

Most scripts can be run directly:

```bash
# Test scripts
python3 scripts/test_openai_connection.py
./scripts/test_backend_api.sh

# Debugging scripts
./scripts/debug_frontend_backend.sh
python3 scripts/check_api_key.py

# Fix scripts
./scripts/fix_502_error.sh us-central1
```

## Note

Main deployment and setup scripts remain in the root directory:
- `setup.sh` - Initial project setup
- `deploy.sh` - Deployment script
- `rebuild_all.sh` - Rebuild all services

