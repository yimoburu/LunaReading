#!/bin/bash
# Automatically set up Cloud SQL connection in .env

echo "🔧 Setting up Cloud SQL Connection"
echo "==================================="
echo ""

# Check for Cloud SQL password file
if [ -f .cloudsql_user_password ]; then
    echo "✅ Found Cloud SQL connection info"
    
    # Extract connection info
    DB_USER=$(grep -E "^DB_USER=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading_user")
    DATABASE_NAME=$(grep -E "^DATABASE_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading")
    CONNECTION_NAME=$(grep -E "^CONNECTION_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "")
    DB_PASSWORD=$(grep -v -E "^(DB_USER|DATABASE_NAME|CONNECTION_NAME)=" .cloudsql_user_password | head -1)
    
    if [ -z "$CONNECTION_NAME" ] || [ -z "$DB_PASSWORD" ]; then
        echo "❌ Incomplete connection info in .cloudsql_user_password"
        exit 1
    fi
    
    echo "Connection Name: $CONNECTION_NAME"
    echo "Database: $DATABASE_NAME"
    echo "User: $DB_USER"
    echo ""
    
    # Check if .env exists
    if [ ! -f .env ]; then
        echo "Creating .env file..."
        touch .env
    fi
    
    # Remove existing Cloud SQL env vars if present
    if grep -q "CLOUDSQL_INSTANCE_CONNECTION_NAME" .env; then
        echo "⚠️  Replacing existing Cloud SQL configuration"
        sed -i.bak '/CLOUDSQL_INSTANCE_CONNECTION_NAME/d' .env
        sed -i.bak '/CLOUDSQL_USER/d' .env
        sed -i.bak '/CLOUDSQL_PASSWORD/d' .env
        sed -i.bak '/CLOUDSQL_DATABASE/d' .env
    fi
    
    # Remove old SQLALCHEMY_DATABASE_URI if present
    if grep -q "SQLALCHEMY_DATABASE_URI" .env; then
        echo "⚠️  Removing deprecated SQLALCHEMY_DATABASE_URI"
        sed -i.bak '/SQLALCHEMY_DATABASE_URI/d' .env
    fi
    
    # Add Cloud SQL connection variables
    echo "" >> .env
    echo "# Cloud SQL connection (using Cloud SQL Connector)" >> .env
    echo "CLOUDSQL_INSTANCE_CONNECTION_NAME=\"$CONNECTION_NAME\"" >> .env
    echo "CLOUDSQL_USER=\"$DB_USER\"" >> .env
    echo "CLOUDSQL_PASSWORD=\"$DB_PASSWORD\"" >> .env
    echo "CLOUDSQL_DATABASE=\"$DATABASE_NAME\"" >> .env
    
    echo "✅ Added Cloud SQL connection configuration to .env"
    echo ""
    echo "📝 Environment variables set:"
    echo "   CLOUDSQL_INSTANCE_CONNECTION_NAME=$CONNECTION_NAME"
    echo "   CLOUDSQL_USER=$DB_USER"
    echo "   CLOUDSQL_DATABASE=$DATABASE_NAME"
    echo ""
    echo "⚠️  Note: This uses Cloud SQL Connector for secure connections."
    echo "   For local development, ensure Application Default Credentials are set:"
    echo "   gcloud auth application-default login"
    
else
    echo "❌ .cloudsql_user_password file not found"
    echo ""
    echo "Options:"
    echo "1. Set up Cloud SQL: ./scripts/setup_cloud_sql.sh"
    echo "2. Manually set environment variables in .env:"
    echo "   CLOUDSQL_INSTANCE_CONNECTION_NAME=project:region:instance"
    echo "   CLOUDSQL_USER=your-username"
    echo "   CLOUDSQL_PASSWORD=your-password"
    echo "   CLOUDSQL_DATABASE=lunareading"
    exit 1
fi
