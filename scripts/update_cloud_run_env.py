#!/usr/bin/env python3
"""
Update Cloud Run service with environment variables from .env file

Usage:
    python3 scripts/update_cloud_run_env.py [SERVICE_NAME] [REGION] [PROJECT_ID]

Example:
    python3 scripts/update_cloud_run_env.py lunareading-backend us-central1
"""

import os
import sys
import subprocess
from pathlib import Path
from dotenv import load_dotenv

def get_env_vars_from_file(env_path):
    """Load environment variables from .env file"""
    env_vars = {}
    
    if not env_path.exists():
        print(f"❌ .env file not found at: {env_path}")
        return None
    
    # Load .env file
    load_dotenv(dotenv_path=env_path, override=True)
    
    # Read all variables from .env
    with open(env_path, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            
            # Skip lines without =
            if '=' not in line:
                continue
            
            # Parse key=value
            parts = line.split('=', 1)
            if len(parts) != 2:
                continue
            
            key = parts[0].strip()
            value = parts[1].strip()
            
            # Remove quotes, but keep one set for password strings
            is_password = any(sensitive in key.upper() for sensitive in ['PASSWORD', 'SECRET', 'API_KEY', 'KEY'])
            if is_password:
                # For passwords: remove all nested quotes, then add back exactly one set
                original_has_quotes = (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'"))
                
                # Strip all quotes (both single and double) until we get to the unquoted content
                while (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
                    value = value[1:-1]
                
                # If original had quotes, add back exactly one set of double quotes
                if original_has_quotes:
                    value = f'"{value}"'
            else:
                # For non-passwords: remove all quotes
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                elif value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]
            
            if key and value:
                env_vars[key] = value
    
    return env_vars

def update_cloud_run_env(service_name, region, project_id, env_vars):
    """Update Cloud Run service with environment variables"""
    if not env_vars:
        print("❌ No environment variables to update")
        return False
    
    # Build env vars string for gcloud
    env_vars_str = ','.join([f"{k}={v}" for k, v in env_vars.items()])
    
    print(f"\n🔄 Updating Cloud Run service: {service_name}")
    print(f"   Region: {region}")
    print(f"   Project: {project_id}")
    print(f"   Environment variables: {len(env_vars)}")
    print("")
    
    # Show variables (mask sensitive ones)
    print("📋 Environment variables to set:")
    for key, value in env_vars.items():
        if any(sensitive in key.upper() for sensitive in ['PASSWORD', 'SECRET', 'API_KEY', 'KEY']):
            display_value = "***"
        else:
            display_value = value
        print(f"   ✅ {key}={display_value}")
    
    print("")
    
    # Confirm
    response = input("⚠️  Continue with update? (y/n): ").strip().lower()
    if response != 'y':
        print("Cancelled.")
        return False
    
    print("\n🔄 Updating Cloud Run service...")
    
    # Run gcloud command
    cmd = [
        'gcloud', 'run', 'services', 'update', service_name,
        '--region', region,
        '--project', project_id,
        '--update-env-vars', env_vars_str,
        '--quiet'
    ]
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("✅ Successfully updated Cloud Run service!")
        print("")
        print("📝 Next steps:")
        print(f"   1. Check logs: gcloud run services logs read {service_name} --region {region} --limit 50")
        print(f"   2. Test service: curl $(gcloud run services describe {service_name} --region {region} --format 'value(status.url)')/")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to update Cloud Run service")
        print(f"   Error: {e.stderr}")
        return False

def main():
    # Get arguments
    service_name = sys.argv[1] if len(sys.argv) > 1 else 'lunareading-backend'
    region = sys.argv[2] if len(sys.argv) > 2 else 'us-central1'
    project_id = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Get project ID from gcloud if not provided
    if not project_id:
        try:
            result = subprocess.run(
                ['gcloud', 'config', 'get-value', 'project'],
                capture_output=True,
                text=True,
                check=True
            )
            project_id = result.stdout.strip()
        except subprocess.CalledProcessError:
            print("❌ Project ID not specified and could not get from gcloud config")
            print("   Usage: python3 scripts/update_cloud_run_env.py [SERVICE_NAME] [REGION] [PROJECT_ID]")
            print("   Or set default project: gcloud config set project PROJECT_ID")
            sys.exit(1)
    
    if not project_id:
        print("❌ Project ID is required")
        sys.exit(1)
    
    print("🔄 Updating Cloud Run Environment Variables")
    print("=" * 50)
    print(f"Service: {service_name}")
    print(f"Region: {region}")
    print(f"Project: {project_id}")
    print("")
    
    # Find .env file
    project_root = Path.cwd()
    env_path = project_root / '.env'
    
    # Load environment variables
    env_vars = get_env_vars_from_file(env_path)
    
    if not env_vars:
        print("❌ No environment variables found in .env file")
        sys.exit(1)
    
    # Update Cloud Run
    success = update_cloud_run_env(service_name, region, project_id, env_vars)
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()

