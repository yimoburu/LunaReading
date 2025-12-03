#!/bin/bash
# Set OpenAI API key in Cloud Run backend service

REGION=${1:-"us-central1"}

echo "🔑 Setting OpenAI API Key"
echo "========================"
echo ""

# Check if key is provided as argument
if [ -n "$2" ]; then
    OPENAI_KEY="$2"
else
    # Prompt for key
    read -p "Enter your OpenAI API key: " OPENAI_KEY
fi

if [ -z "$OPENAI_KEY" ]; then
    echo "❌ API key cannot be empty"
    exit 1
fi

echo ""
echo "Setting OPENAI_API_KEY in backend service..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --update-env-vars "OPENAI_API_KEY=$OPENAI_KEY" \
  --quiet

if [ $? -eq 0 ]; then
    echo "✅ API key set successfully!"
    echo ""
    echo "The backend will now be able to generate questions and evaluate answers."
    echo ""
    echo "Test it by creating a reading session in the frontend."
else
    echo "❌ Failed to set API key"
    exit 1
fi

