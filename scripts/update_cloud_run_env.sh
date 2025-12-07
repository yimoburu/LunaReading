#!/bin/bash
# Update Cloud Run service with environment variables from .env file
#
# Usage: ./scripts/update_cloud_run_env.sh [SERVICE_NAME] [REGION]
# Example: ./scripts/update_cloud_run_env.sh lunareading-backend us-central1

set -e

SERVICE_NAME=${1:-"lunareading-backend"}
REGION=${2:-"us-central1"}
PROJECT_ID=${3:-$(gcloud config get-value project 2>/dev/null)}

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not specified"
    echo "Usage: $0 [SERVICE_NAME] [REGION] [PROJECT_ID]"
    echo "   Or set default project: gcloud config set project PROJECT_ID"
    exit 1
fi

echo "🔄 Updating Cloud Run Environment Variables"
echo "==========================================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo "Project: $PROJECT_ID"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found in current directory"
    echo "   Make sure you're running this from the project root"
    exit 1
fi

echo "📋 Reading environment variables from .env file..."
echo ""

# Parse .env file and build env vars string
ENV_VARS=""
ENV_COUNT=0

while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Skip lines that don't have = sign
    if [[ ! "$line" =~ = ]]; then
        continue
    fi
    
    # Extract key and value
    KEY=$(echo "$line" | cut -d'=' -f1 | xargs)
    VALUE=$(echo "$line" | cut -d'=' -f2- | xargs)
    
    # Remove quotes if present
    VALUE=$(echo "$VALUE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Skip if key or value is empty
    if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
        continue
    fi
    
    # Skip sensitive values in output (mask password)
    if [[ "$KEY" == *"PASSWORD"* ]] || [[ "$KEY" == *"SECRET"* ]] || [[ "$KEY" == *"API_KEY"* ]]; then
        DISPLAY_VALUE="***"
    else
        DISPLAY_VALUE="$VALUE"
    fi
    
    echo "   ✅ $KEY=$DISPLAY_VALUE"
    
    # Build env vars string for gcloud
    if [ -z "$ENV_VARS" ]; then
        ENV_VARS="${KEY}=${VALUE}"
    else
        ENV_VARS="${ENV_VARS},${KEY}=${VALUE}"
    fi
    
    ENV_COUNT=$((ENV_COUNT + 1))
done < .env

if [ $ENV_COUNT -eq 0 ]; then
    echo "❌ No environment variables found in .env file"
    exit 1
fi

echo ""
echo "📊 Found $ENV_COUNT environment variable(s)"
echo ""

# Confirm before updating
echo "⚠️  This will update the Cloud Run service with these environment variables."
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🔄 Updating Cloud Run service..."
echo ""

# Update Cloud Run service
gcloud run services update "$SERVICE_NAME" \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --update-env-vars "$ENV_VARS" \
    --quiet

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully updated Cloud Run service!"
    echo ""
    echo "📝 Next steps:"
    echo "   1. The service will restart with new environment variables"
    echo "   2. Check logs: gcloud run services logs read $SERVICE_NAME --region $REGION --limit 50"
    echo "   3. Test the service: curl \$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')/"
else
    echo ""
    echo "❌ Failed to update Cloud Run service"
    echo "   Check the error message above"
    exit 1
fi

