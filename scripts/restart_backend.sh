#!/bin/bash
# Script to help restart the backend server

echo "🔄 Backend Server Restart Helper"
echo "================================"
echo ""
echo "To fix the OpenAI API key issue:"
echo ""
echo "1. Stop the current backend server (press Ctrl+C in the terminal where it's running)"
echo ""
echo "2. Restart the backend server:"
echo "   cd backend"
echo "   source ../.venv/bin/activate"
echo "   python app.py"
echo ""
echo "3. The server should now load the correct API key from .env"
echo ""
echo "Current .env location: $(pwd)/.env"
echo ""

# Check if API key exists
if grep -q "OPENAI_API_KEY=" .env 2>/dev/null; then
    API_KEY=$(grep "OPENAI_API_KEY=" .env | cut -d'=' -f2)
    if [ "${API_KEY}" != "your-openai-api-key-here" ] && [ -n "${API_KEY}" ]; then
        echo "✅ OPENAI_API_KEY found in .env file"
        echo "   Key starts with: ${API_KEY:0:20}..."
    else
        echo "⚠️  OPENAI_API_KEY is using placeholder value"
    fi
else
    echo "❌ OPENAI_API_KEY not found in .env file"
fi

