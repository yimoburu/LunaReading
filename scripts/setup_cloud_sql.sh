#!/bin/bash
# Setup Cloud SQL MySQL instance for LunaReading

set -e

PROJECT_ID=${1:-$(gcloud config get-value project 2>/dev/null)}
REGION=${2:-"us-central1"}
INSTANCE_NAME=${3:-"lunareading-db"}
DATABASE_NAME=${4:-"lunareading"}
DB_USER=${5:-"lunareading_user"}
TIER=${6:-"db-f1-micro"}  # db-f1-micro is the smallest/cheapest tier

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not specified and gcloud project not set"
    echo ""
    echo "Usage: $0 [PROJECT_ID] [REGION] [INSTANCE_NAME] [DATABASE_NAME] [DB_USER] [TIER]"
    echo ""
    echo "Example:"
    echo "  $0 lunareading-app us-central1 lunareading-db lunareading lunareading_user db-f1-micro"
    echo ""
    echo "Or set gcloud project first:"
    echo "  gcloud config set project YOUR_PROJECT_ID"
    echo "  $0"
    exit 1
fi

echo "☁️  Setting up Cloud SQL MySQL Instance"
echo "========================================"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Instance Name: $INSTANCE_NAME"
echo "Database Name: $DATABASE_NAME"
echo "Database User: $DB_USER"
echo "Tier: $TIER"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Set project
echo "📋 Setting Google Cloud project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo ""
echo "🔧 Enabling required APIs..."
gcloud services enable sqladmin.googleapis.com --quiet || true
gcloud services enable servicenetworking.googleapis.com --quiet || true

# Check if instance already exists
echo ""
echo "🔍 Checking if instance already exists..."
if gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "⚠️  Instance '$INSTANCE_NAME' already exists!"
    read -p "Continue with existing instance? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    INSTANCE_EXISTS=true
else
    INSTANCE_EXISTS=false
fi

# Create instance if it doesn't exist
if [ "$INSTANCE_EXISTS" = false ]; then
    echo ""
    echo "🏗️  Creating Cloud SQL MySQL instance..."
    echo "   This may take 5-10 minutes..."
    
    # Generate root password
    ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo "   Generated root password (saved to .cloudsql_password)"
    echo "$ROOT_PASSWORD" > .cloudsql_password
    chmod 600 .cloudsql_password
    
    gcloud sql instances create $INSTANCE_NAME \
        --database-version=MYSQL_8_0 \
        --tier=$TIER \
        --region=$REGION \
        --root-password=$ROOT_PASSWORD \
        --storage-type=SSD \
        --storage-size=10GB \
        --storage-auto-increase \
        --backup-start-time=03:00 \
        --enable-bin-log \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=4 \
        --project=$PROJECT_ID
    
    echo "✅ Instance created successfully!"
else
    echo "✅ Using existing instance"
    if [ -f .cloudsql_password ]; then
        ROOT_PASSWORD=$(cat .cloudsql_password)
    else
        echo "⚠️  Root password file not found. You may need to reset password."
        read -p "Enter root password (or press Enter to skip): " -s ROOT_PASSWORD
        echo ""
    fi
fi

# Get instance connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --format='value(connectionName)')

echo ""
echo "📊 Instance Information:"
echo "   Connection Name: $CONNECTION_NAME"
echo "   Public IP: $(gcloud sql instances describe $INSTANCE_NAME --format='value(ipAddresses[0].ipAddress)' 2>/dev/null || echo 'Not assigned')"
echo ""

# Create database
echo "📦 Creating database '$DATABASE_NAME'..."
if gcloud sql databases describe $DATABASE_NAME --instance=$INSTANCE_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "⚠️  Database '$DATABASE_NAME' already exists"
else
    gcloud sql databases create $DATABASE_NAME \
        --instance=$INSTANCE_NAME \
        --project=$PROJECT_ID
    echo "✅ Database created"
fi

# Create database user
echo ""
echo "👤 Creating database user '$DB_USER'..."
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    # Save password and connection info
    {
        echo "DB_USER=$DB_USER"
        echo "DATABASE_NAME=$DATABASE_NAME"
        echo "CONNECTION_NAME=$CONNECTION_NAME"
        echo "$DB_PASSWORD"
    } > .cloudsql_user_password
    chmod 600 .cloudsql_user_password
    echo "   Generated user password (saved to .cloudsql_user_password)"
fi

# Check if user exists
if gcloud sql users list --instance=$INSTANCE_NAME --project=$PROJECT_ID 2>/dev/null | grep -q "^$DB_USER"; then
    echo "⚠️  User '$DB_USER' already exists"
    read -p "Reset password? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gcloud sql users set-password $DB_USER \
            --instance=$INSTANCE_NAME \
            --password=$DB_PASSWORD \
            --project=$PROJECT_ID
        echo "✅ Password updated"
    fi
else
    gcloud sql users create $DB_USER \
        --instance=$INSTANCE_NAME \
        --password=$DB_PASSWORD \
        --project=$PROJECT_ID
    echo "✅ User created"
fi

# Get Cloud Run service account
echo ""
echo "🔗 Getting Cloud Run service account..."
SERVICE_ACCOUNT=$(gcloud run services describe lunareading-backend \
    --region=$REGION \
    --format='value(spec.template.spec.serviceAccountName)' \
    2>/dev/null || echo "")

if [ -z "$SERVICE_ACCOUNT" ]; then
    # Use default compute service account
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
    SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    echo "   Using default compute service account: $SERVICE_ACCOUNT"
else
    echo "   Service account: $SERVICE_ACCOUNT"
fi

# Grant Cloud SQL Client role
echo ""
echo "🔐 Granting Cloud SQL Client permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/cloudsql.client" \
    --quiet || echo "⚠️  Permission may already be granted"

# Build connection string
CONNECTION_STRING="mysql+pymysql://${DB_USER}:${DB_PASSWORD}@/${DATABASE_NAME}?unix_socket=/cloudsql/${CONNECTION_NAME}"

echo ""
echo "✅ Cloud SQL setup complete!"
echo ""
echo "📝 Connection Information:"
echo "   Connection Name: $CONNECTION_NAME"
echo "   Database: $DATABASE_NAME"
echo "   User: $DB_USER"
echo "   Password: Saved to .cloudsql_user_password"
echo ""
echo "🔗 Connection String (for app.py):"
echo "   $CONNECTION_STRING"
echo ""
echo "📋 Next Steps:"
echo "   1. Update Cloud Run service to use Cloud SQL:"
echo "      ./scripts/update_cloud_run_db.sh $REGION"
echo ""
echo "   2. Migrate data from SQLite to MySQL:"
echo "      python3 scripts/migrate_to_mysql.py"
echo ""
echo "   3. Restart Cloud Run service to apply changes"
echo ""
echo "💾 Passwords saved to:"
echo "   - .cloudsql_password (root password)"
echo "   - .cloudsql_user_password (database user password)"
echo "   ⚠️  Keep these files secure and add them to .gitignore!"

