"""
Configuration management for LunaReading backend

This module requires Google Cloud SQL for database operations.
"""

import os
import sys
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv

# Load .env from project root (only if .env file exists)
# In Cloud Run, environment variables are set directly, so .env file is optional
try:
    project_root = Path(__file__).parent.parent
except NameError:
    project_root = Path.cwd().parent if Path.cwd().name == 'backend' else Path.cwd()

env_path = project_root / '.env'
if env_path.exists():
    load_dotenv(dotenv_path=env_path, override=True)
else:
    # In Cloud Run, env vars are set directly, so .env file is not needed
    load_dotenv(override=False)  # Still try to load from environment

# Verify OpenAI API key is loaded (only log in development, not in Cloud Run)
# In Cloud Run, avoid excessive logging during startup
if not os.getenv('PORT'):  # Only log if not running in Cloud Run (PORT env var indicates Cloud Run)
    api_key_check = os.getenv('OPENAI_API_KEY')
    if api_key_check and api_key_check != 'your-openai-api-key-here':
        print(f"✅ OpenAI API key loaded successfully")
    else:
        print(f"⚠️  WARNING: OpenAI API key not found or using placeholder")


class Config:
    """Base configuration class - Google Cloud SQL required"""
    
    # Cloud SQL configuration
    CLOUDSQL_INSTANCE_CONNECTION_NAME = os.getenv('CLOUDSQL_INSTANCE_CONNECTION_NAME')
    CLOUDSQL_DATABASE = os.getenv('CLOUDSQL_DATABASE', 'lunareading')
    CLOUDSQL_USER = os.getenv('CLOUDSQL_USER')
    CLOUDSQL_PASSWORD = os.getenv('CLOUDSQL_PASSWORD')
    
    # Don't raise exceptions during class definition - validate later
    # This allows the app to start even if env vars aren't set yet
    # Validation will happen when database is actually used
    
    # JWT configuration
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'your-secret-key-change-in-production')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)
    
    # OpenAI configuration
    OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
    
    @staticmethod
    def get_env_path():
        """Get the path to .env file"""
        return env_path
    
    @staticmethod
    def validate_database():
        """Validate Cloud SQL configuration (non-blocking, just checks env vars)"""
        # Only validate that env vars are set, don't try to connect
        # This ensures fast startup
        pass
    
    @staticmethod
    def diagnose_connection_error(error):
        """
        Diagnose Cloud SQL connection errors and provide helpful messages
        
        Args:
            error: Exception object from database connection attempt
            
        Returns:
            str: Diagnostic message with suggested fixes
        """
        error_str = str(error).lower()
        
        diagnostics = []
        diagnostics.append("🔍 Cloud SQL Connection Diagnostics:")
        diagnostics.append("")
        
        # Check for common error patterns
        if 'credentials' in error_str or 'authentication' in error_str or 'access denied' in error_str:
            diagnostics.append("❌ Authentication failed")
            diagnostics.append("")
            diagnostics.append("Possible causes:")
            diagnostics.append("  1. Incorrect username or password")
            diagnostics.append("     → Verify CLOUDSQL_USER and CLOUDSQL_PASSWORD in .env file")
            diagnostics.append("")
            diagnostics.append("  2. User doesn't exist in database")
            diagnostics.append("     → Create user: gcloud sql users create USER --instance=INSTANCE")
            diagnostics.append("")
        
        elif 'instance' in error_str and ('not found' in error_str or 'invalid' in error_str):
            diagnostics.append("❌ Invalid instance connection name")
            diagnostics.append("")
            diagnostics.append("Solution:")
            diagnostics.append("  → Verify CLOUDSQL_INSTANCE_CONNECTION_NAME in .env file")
            diagnostics.append("  → Format: project:region:instance")
            diagnostics.append("  → Check: gcloud sql instances list")
            diagnostics.append("")
        
        elif 'database' in error_str and ('not found' in error_str or 'doesn\'t exist' in error_str):
            diagnostics.append("❌ Database does not exist")
            diagnostics.append("")
            diagnostics.append("Solution:")
            diagnostics.append("  → Database will be created automatically on first use")
            diagnostics.append("  → Or create manually: gcloud sql databases create DATABASE --instance=INSTANCE")
            diagnostics.append("")
        
        elif 'permission denied' in error_str or 'forbidden' in error_str:
            diagnostics.append("❌ Permission denied")
            diagnostics.append("")
            diagnostics.append("Possible causes:")
            diagnostics.append("  1. Service account doesn't have Cloud SQL Client role")
            diagnostics.append("     → Grant role: gcloud projects add-iam-policy-binding PROJECT_ID \\")
            diagnostics.append("         --member='serviceAccount:SERVICE_ACCOUNT' \\")
            diagnostics.append("         --role='roles/cloudsql.client'")
            diagnostics.append("")
            diagnostics.append("  2. Cloud SQL Connector not properly configured")
            diagnostics.append("     → Ensure google-cloud-sql-connector is installed")
            diagnostics.append("")
        
        elif 'connection' in error_str and ('refused' in error_str or 'failed' in error_str):
            diagnostics.append("❌ Connection failed")
            diagnostics.append("")
            diagnostics.append("Possible causes:")
            diagnostics.append("  1. Cloud SQL instance is not running")
            diagnostics.append("     → Check: gcloud sql instances list")
            diagnostics.append("")
            diagnostics.append("  2. Network connectivity issues")
            diagnostics.append("     → Verify you can reach the Cloud SQL instance")
            diagnostics.append("")
        
        else:
            diagnostics.append(f"❌ Connection error: {error}")
            diagnostics.append("")
            diagnostics.append("General troubleshooting:")
            diagnostics.append("  1. Verify CLOUDSQL_INSTANCE_CONNECTION_NAME is set correctly")
            diagnostics.append("  2. Check Cloud SQL instance status")
            diagnostics.append("  3. Verify credentials are valid")
            diagnostics.append("  4. Ensure Cloud SQL Admin API is enabled")
            diagnostics.append("")
        
        diagnostics.append(f"Current configuration:")
        diagnostics.append(f"  Instance: {Config.CLOUDSQL_INSTANCE_CONNECTION_NAME}")
        diagnostics.append(f"  Database: {Config.CLOUDSQL_DATABASE}")
        diagnostics.append(f"  User: {Config.CLOUDSQL_USER}")
        diagnostics.append("")
        diagnostics.append("For more help, see: https://cloud.google.com/sql/docs")
        
        return "\n".join(diagnostics)
