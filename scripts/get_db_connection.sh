#!/bin/bash
# Get and display Cloud SQL connection information

echo "🔍 Finding Cloud SQL Connection Information"
echo "==========================================="
echo ""

# Check for Cloud SQL password file
if [ -f .cloudsql_user_password ]; then
    echo "✅ Found .cloudsql_user_password file"
    echo ""
    
    # Extract connection info
    CONNECTION_NAME=$(grep -E "^CONNECTION_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "")
    DB_USER=$(grep -E "^DB_USER=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading_user")
    DATABASE_NAME=$(grep -E "^DATABASE_NAME=" .cloudsql_user_password 2>/dev/null | cut -d'=' -f2 || echo "lunareading")
    DB_PASSWORD=$(grep -v -E "^(DB_USER|DATABASE_NAME|CONNECTION_NAME)=" .cloudsql_user_password | head -1)
    
    if [ -n "$CONNECTION_NAME" ] && [ -n "$DB_PASSWORD" ]; then
        echo "📋 Connection Details:"
        echo "   Connection Name: $CONNECTION_NAME"
        echo "   Database: $DATABASE_NAME"
        echo "   User: $DB_USER"
        echo ""
        echo "📝 To use this connection, add to your .env file:"
        echo "   CLOUDSQL_INSTANCE_CONNECTION_NAME=\"$CONNECTION_NAME\""
        echo "   CLOUDSQL_USER=\"$DB_USER\""
        echo "   CLOUDSQL_PASSWORD=\"$DB_PASSWORD\""
        echo "   CLOUDSQL_DATABASE=\"$DATABASE_NAME\""
        echo ""
        
        # Check if it's already in .env
        if [ -f .env ]; then
            if grep -q "CLOUDSQL_INSTANCE_CONNECTION_NAME" .env; then
                echo "✅ Cloud SQL configuration already exists in .env"
                echo "   Current values:"
                grep "CLOUDSQL_" .env | sed 's/PASSWORD=.*/PASSWORD=***/' || true
            else
                echo "💡 Would you like to add this to .env? (y/n)"
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    echo "" >> .env
                    echo "# Cloud SQL connection (using Cloud SQL Connector)" >> .env
                    echo "CLOUDSQL_INSTANCE_CONNECTION_NAME=\"$CONNECTION_NAME\"" >> .env
                    echo "CLOUDSQL_USER=\"$DB_USER\"" >> .env
                    echo "CLOUDSQL_PASSWORD=\"$DB_PASSWORD\"" >> .env
                    echo "CLOUDSQL_DATABASE=\"$DATABASE_NAME\"" >> .env
                    echo "✅ Added to .env file"
                fi
            fi
        else
            echo "💡 Would you like to create .env file with this connection? (y/n)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo "# Cloud SQL connection (using Cloud SQL Connector)" > .env
                echo "CLOUDSQL_INSTANCE_CONNECTION_NAME=\"$CONNECTION_NAME\"" >> .env
                echo "CLOUDSQL_USER=\"$DB_USER\"" >> .env
                echo "CLOUDSQL_PASSWORD=\"$DB_PASSWORD\"" >> .env
                echo "CLOUDSQL_DATABASE=\"$DATABASE_NAME\"" >> .env
                echo "✅ Created .env file"
            fi
        fi
    else
        echo "⚠️  Connection info incomplete in .cloudsql_user_password"
        echo "   Missing: CONNECTION_NAME or password"
    fi
else
    echo "❌ .cloudsql_user_password file not found"
    echo ""
    echo "📋 Options to get connection info:"
    echo ""
    echo "1. If you have Cloud SQL instance set up:"
    echo "   Run: ./scripts/setup_cloud_sql.sh"
    echo ""
    echo "2. If Cloud SQL is already set up, get connection name:"
    echo "   gcloud sql instances list"
    echo "   gcloud sql instances describe INSTANCE_NAME --format='value(connectionName)'"
    echo ""
    echo "3. For local development with Cloud SQL (using Cloud SQL Proxy):"
    echo "   - Install Cloud SQL Proxy"
    echo "   - Run: cloud_sql_proxy -instances=PROJECT:REGION:INSTANCE=tcp:3306"
    echo "   - Set environment variables in .env"
fi

echo ""
echo "📖 For more information, see:"
echo "   - docs/CLOUDSQL_CONNECTOR_MIGRATION.md"
echo "   - docs/DATABASE_CONNECTION.md"
echo "   - scripts/setup_cloud_sql.sh"
