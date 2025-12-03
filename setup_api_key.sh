#!/bin/bash
# Helper script to set up OpenAI API key in .env file

echo "🔑 OpenAI API Key Setup"
echo "======================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✅ .env file created"
    else
        echo "⚠️  .env.example not found, creating new .env file..."
        cat > .env <<EOF
OPENAI_API_KEY=your-openai-api-key-here
JWT_SECRET_KEY=$(openssl rand -hex 32)
EOF
        echo "✅ .env file created with default values"
    fi
fi

echo ""
echo "Current .env file location: $(pwd)/.env"
echo ""

# Check current API key status
if grep -q "OPENAI_API_KEY=" .env 2>/dev/null; then
    CURRENT_KEY=$(grep "OPENAI_API_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    if [ "${CURRENT_KEY}" = "your-openai-api-key-here" ] || [ -z "${CURRENT_KEY}" ]; then
        echo "⚠️  Current API key is not set or using placeholder"
        echo ""
        echo "To set your API key:"
        echo "1. Get your API key from: https://platform.openai.com/api-keys"
        echo "2. Edit .env file and replace 'your-openai-api-key-here' with your actual key"
        echo ""
        read -p "Would you like to set it now? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your OpenAI API key: " NEW_KEY
            if [ -n "$NEW_KEY" ]; then
                # Update .env file
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    sed -i '' "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" .env
                else
                    # Linux
                    sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" .env
                fi
                echo "✅ API key updated in .env file"
                echo ""
                echo "⚠️  If the backend server is running, restart it to load the new API key"
            else
                echo "❌ API key cannot be empty"
            fi
        fi
    else
        echo "✅ API key is already set"
        echo "   Key starts with: ${CURRENT_KEY:0:20}..."
        echo "   Key length: ${#CURRENT_KEY} characters"
        if [[ "$CURRENT_KEY" == sk-* ]]; then
            echo "   ✅ Format looks correct (starts with 'sk-')"
        else
            echo "   ⚠️  Format might be incorrect (should start with 'sk-')"
        fi
        echo ""
        read -p "Would you like to update it? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your new OpenAI API key: " NEW_KEY
            if [ -n "$NEW_KEY" ]; then
                # Update .env file
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    sed -i '' "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" .env
                else
                    # Linux
                    sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" .env
                fi
                echo "✅ API key updated in .env file"
                echo ""
                echo "⚠️  If the backend server is running, restart it to load the new API key"
            else
                echo "❌ API key cannot be empty"
            fi
        fi
    fi
else
    echo "❌ OPENAI_API_KEY not found in .env file"
    echo "Adding it now..."
    read -p "Enter your OpenAI API key: " NEW_KEY
    if [ -n "$NEW_KEY" ]; then
        echo "OPENAI_API_KEY=$NEW_KEY" >> .env
        echo "✅ API key added to .env file"
    else
        echo "❌ API key cannot be empty"
    fi
fi

echo ""
echo "📝 To verify the API key is working, run:"
echo "   python3 check_api_key.py"
echo ""
echo "📝 To test the OpenAI connection, run:"
echo "   python3 test_openai_connection.py"

