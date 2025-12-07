#!/bin/bash
# Grant necessary permissions to database user

echo "🔐 Granting database permissions..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ ERROR: .env file not found"
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$CLOUDSQL_INSTANCE_CONNECTION_NAME" ]; then
    echo "❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set in .env"
    exit 1
fi

if [ -z "$CLOUDSQL_USER" ]; then
    echo "❌ ERROR: CLOUDSQL_USER not set in .env"
    exit 1
fi

DATABASE=${CLOUDSQL_DATABASE:-lunareading}

# Extract instance name
INSTANCE_NAME=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f3)
PROJECT_ID=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f1)

echo "Configuration:"
echo "  Instance: $INSTANCE_NAME"
echo "  Database: $DATABASE"
echo "  User: $CLOUDSQL_USER"
echo ""

# Check if database is a system database
if [ "$DATABASE" = "mysql" ] || [ "$DATABASE" = "information_schema" ] || [ "$DATABASE" = "performance_schema" ] || [ "$DATABASE" = "sys" ]; then
    echo "❌ ERROR: Cannot use system database '$DATABASE'"
    echo ""
    echo "Please set CLOUDSQL_DATABASE to a non-system database name in your .env file:"
    echo "  CLOUDSQL_DATABASE=lunareading"
    echo ""
    echo "Then create the database:"
    echo "  gcloud sql databases create lunareading --instance=$INSTANCE_NAME"
    exit 1
fi

echo "⚠️  Note: Cloud SQL users created via gcloud have limited permissions."
echo "   For full database operations, you may need to:"
echo ""
echo "   1. Use a root/admin user, OR"
echo "   2. Grant permissions manually via SQL"
echo ""

echo "Option 1: Grant permissions via SQL (recommended)"
echo "---------------------------------------------------"
echo "Run this SQL command to grant all privileges:"
echo ""
echo "GRANT ALL PRIVILEGES ON \`$DATABASE\`.* TO '$CLOUDSQL_USER'@'%';"
echo "FLUSH PRIVILEGES;"
echo ""
echo "You can run this using:"
echo "  python3 scripts/grant_permissions_sql.py"
echo ""

echo "Option 2: Create database with proper user"
echo "-------------------------------------------"
echo "1. Create the database:"
echo "   gcloud sql databases create $DATABASE --instance=$INSTANCE_NAME"
echo ""
echo "2. The user should automatically have permissions on the database"
echo ""

echo "Option 3: Use root user (if available)"
echo "--------------------------------------"
echo "If you have root access, you can grant permissions:"
echo "  mysql -h [HOST] -u root -p"
echo "  GRANT ALL PRIVILEGES ON \`$DATABASE\`.* TO '$CLOUDSQL_USER'@'%';"
echo "  FLUSH PRIVILEGES;"
echo ""

