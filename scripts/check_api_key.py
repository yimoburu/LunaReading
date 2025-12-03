#!/usr/bin/env python3
"""Check OpenAI API key configuration"""
import os
from dotenv import load_dotenv
from pathlib import Path

# Load .env from project root (same as backend/app.py)
project_root = Path(__file__).parent
env_path = project_root / '.env'
load_dotenv(dotenv_path=env_path, override=True)

api_key = os.getenv('OPENAI_API_KEY')
print(f"API Key: {api_key}")

print("OpenAI API Key Configuration Check\n")
print("=" * 60)

if not api_key:
    print("❌ OPENAI_API_KEY is not set in .env file")
    print("\nTo fix:")
    print("1. Open the .env file")
    print("2. Add: OPENAI_API_KEY=your-actual-api-key-here")
    print("3. Get your API key from: https://platform.openai.com/api-keys")
elif api_key == 'your-openai-api-key-here':
    print("❌ OPENAI_API_KEY is using the placeholder value")
    print("\nTo fix:")
    print("1. Open the .env file")
    print("2. Replace 'your-openai-api-key-here' with your actual API key")
    print("3. Get your API key from: https://platform.openai.com/api-keys")
else:
    print(f"✅ API Key found")
    print(f"   Length: {len(api_key)} characters")
    print(f"   Starts with: {api_key[:7]}...")
    print(f"   Ends with: ...{api_key[-4:]}")
    
    if api_key.startswith('sk-'):
        print("   ✅ Format looks correct (starts with 'sk-')")
    else:
        print("   ⚠️  Format might be incorrect (should start with 'sk-')")
    
    print("\n⚠️  If you're getting authentication errors:")
    print("   1. Verify the key is correct at https://platform.openai.com/api-keys")
    print("   2. Check if the key has expired or been revoked")
    print("   3. Ensure you have credits/billing set up on your OpenAI account")
    print("   4. Try generating a new API key")

print("=" * 60)

