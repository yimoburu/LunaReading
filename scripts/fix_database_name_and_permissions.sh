#!/bin/bash
# Fix database name and permissions issues

echo "🔧 Fixing database configuration..."
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

# Extract instance name
INSTANCE_NAME=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f3)
PROJECT_ID=$(echo "$CLOUDSQL_INSTANCE_CONNECTION_NAME" | cut -d: -f1)

CURRENT_DB=${CLOUDSQL_DATABASE:-mysql}

echo "Current configuration:"
echo "  Instance: $INSTANCE_NAME"
echo "  Current Database: $CURRENT_DB"
echo "  User: $CLOUDSQL_USER"
echo ""

# Check if using system database
if [ "$CURRENT_DB" = "mysql" ] || [ "$CURRENT_DB" = "information_schema" ] || [ "$CURRENT_DB" = "performance_schema" ] || [ "$CURRENT_DB" = "sys" ]; then
    echo "❌ PROBLEM: You're using system database '$CURRENT_DB'"
    echo ""
    echo "This is not allowed. You need to use a user database."
    echo ""
    
    # Check if lunareading database exists
    echo "Checking if 'lunareading' database exists..."
    gcloud sql databases list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" 2>&1 | grep -q "lunareading"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database 'lunareading' exists"
        echo ""
        echo "Fix: Update your .env file:"
        echo "  CLOUDSQL_DATABASE=lunareading"
    else
        echo "⚠️  Database 'lunareading' does not exist"
        echo ""
        echo "Creating database 'lunareading'..."
        gcloud sql databases create lunareading --instance="$INSTANCE_NAME" --project="$PROJECT_ID"
        
        if [ $? -eq 0 ]; then
            echo "✅ Database 'lunareading' created"
            echo ""
            echo "Update your .env file:"
            echo "  CLOUDSQL_DATABASE=lunareading"
        else
            echo "❌ Failed to create database"
            exit 1
        fi
    fi
    
    echo ""
    echo "After updating .env, run:"
    echo "  ./scripts/initialize_database.sh"
    exit 1
fi

echo "✅ Database name is correct: $CURRENT_DB"
echo ""

# Check if database exists
echo "Checking if database exists..."
gcloud sql databases list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" 2>&1 | grep -q "$CURRENT_DB"

if [ $? -ne 0 ]; then
    echo "⚠️  Database '$CURRENT_DB' does not exist"
    echo "Creating database..."
    gcloud sql databases create "$CURRENT_DB" --instance="$INSTANCE_NAME" --project="$PROJECT_ID"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database created"
    else
        echo "❌ Failed to create database"
        exit 1
    fi
else
    echo "✅ Database '$CURRENT_DB' exists"
fi

echo ""
echo "Step 2: Checking user permissions..."
echo "-------------------------------------"
echo "The user '$CLOUDSQL_USER' needs CREATE, INSERT, UPDATE, DELETE, SELECT permissions."
echo ""
echo "To grant permissions, you have two options:"
echo ""
echo "Option 1: Use root/admin user (if available)"
echo "  Set in .env:"
echo "    CLOUDSQL_ROOT_USER=root"
echo "    CLOUDSQL_ROOT_PASSWORD=your_root_password"
echo "  Then run:"
echo "    python3 scripts/grant_permissions_sql.py"
echo ""
echo "Option 2: Grant via Cloud SQL Console"
echo "  1. Go to Cloud SQL Console"
echo "  2. Select your instance"
echo "  3. Go to Users tab"
echo "  4. Edit user '$CLOUDSQL_USER'"
echo "  5. Or run SQL: GRANT ALL PRIVILEGES ON \`$CURRENT_DB\`.* TO '$CLOUDSQL_USER'@'%';"
echo ""
echo "After granting permissions, run:"
echo "  ./scripts/initialize_database.sh"


