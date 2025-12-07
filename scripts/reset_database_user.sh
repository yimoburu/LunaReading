#!/bin/bash
# Reset database user password or create new user

echo "🔐 Database User Management"
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

echo "Configuration:"
echo "  Instance: $INSTANCE_NAME"
echo "  User: $CLOUDSQL_USER"
echo "  Project: $PROJECT_ID"
echo ""

# Check if user exists
echo "Checking if user exists..."
gcloud sql users list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" 2>&1 | grep -q "$CLOUDSQL_USER"

if [ $? -eq 0 ]; then
    echo "✅ User '$CLOUDSQL_USER' exists"
    echo ""
    echo "Option 1: Reset password for existing user"
    echo "------------------------------------------"
    read -sp "Enter new password for user '$CLOUDSQL_USER': " NEW_PASSWORD
    echo ""
    
    if [ -z "$NEW_PASSWORD" ]; then
        echo "❌ Password cannot be empty"
        exit 1
    fi
    
    echo "Resetting password..."
    gcloud sql users set-password "$CLOUDSQL_USER" \
        --instance="$INSTANCE_NAME" \
        --project="$PROJECT_ID" \
        --password="$NEW_PASSWORD"
    
    if [ $? -eq 0 ]; then
        echo "✅ Password reset successfully"
        echo ""
        echo "⚠️  IMPORTANT: Update your .env file with the new password:"
        echo "   CLOUDSQL_PASSWORD=$NEW_PASSWORD"
    else
        echo "❌ Failed to reset password"
        exit 1
    fi
else
    echo "⚠️  User '$CLOUDSQL_USER' does not exist"
    echo ""
    echo "Option 2: Create new user"
    echo "-------------------------"
    read -sp "Enter password for new user '$CLOUDSQL_USER': " NEW_PASSWORD
    echo ""
    
    if [ -z "$NEW_PASSWORD" ]; then
        echo "❌ Password cannot be empty"
        exit 1
    fi
    
    echo "Creating user..."
    gcloud sql users create "$CLOUDSQL_USER" \
        --instance="$INSTANCE_NAME" \
        --project="$PROJECT_ID" \
        --password="$NEW_PASSWORD"
    
    if [ $? -eq 0 ]; then
        echo "✅ User created successfully"
        echo ""
        echo "⚠️  IMPORTANT: Update your .env file with the password:"
        echo "   CLOUDSQL_PASSWORD=$NEW_PASSWORD"
    else
        echo "❌ Failed to create user"
        exit 1
    fi
fi

echo ""
echo "Next steps:"
echo "  1. Update .env file with the correct password"
echo "  2. Test connection: ./scripts/fix_database_authentication.sh"
echo "  3. Initialize database: ./scripts/initialize_database.sh"

