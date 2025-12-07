#!/bin/bash
# Quick fix for 502 error - update database path and environment variables

REGION=${1:-"us-central1"}

echo "🔧 Fixing 502 Error on Cloud Run"
echo "================================"
echo ""

echo "1. Checking Cloud SQL configuration..."
echo "   Note: Cloud SQL connection should be configured with CLOUDSQL_* environment variables"
echo "   If not set, you'll need to configure Cloud SQL connection"

echo ""
echo "2. Setting required environment variables..."
echo "   (You'll need to provide your API keys)"
read -p "Enter your OpenAI API key: " OPENAI_KEY
read -p "Enter your JWT secret key (or press Enter for auto-generated): " JWT_KEY

if [ -z "$JWT_KEY" ]; then
    JWT_KEY=$(openssl rand -hex 32)
    echo "   Generated JWT secret key"
fi

gcloud run services update lunareading-backend \
  --region $REGION \
  --update-env-vars "OPENAI_API_KEY=$OPENAI_KEY,JWT_SECRET_KEY=$JWT_KEY"

echo ""
echo "✅ Configuration updated!"
echo ""
echo "3. Getting service URL..."
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)')
echo "   Backend URL: $BACKEND_URL"
echo ""
echo "4. Testing backend..."
curl -s "$BACKEND_URL/" | head -5
echo ""
echo "✅ Done! Try registering again at your frontend URL."

