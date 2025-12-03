#!/usr/bin/env python3
"""Test OpenAI API connection"""
import sys
sys.path.insert(0, 'backend')

from app import app, call_openai
import os
from dotenv import load_dotenv

load_dotenv()

print("Testing OpenAI API connection...\n")

# Check API key
api_key = os.getenv('OPENAI_API_KEY')
if not api_key or api_key == 'your-openai-api-key-here':
    print("❌ ERROR: OPENAI_API_KEY is not set or using placeholder")
    print("   Please set your API key in the .env file")
    sys.exit(1)

print(f"✅ API Key found: {api_key[:10]}...{api_key[-4:]}\n")

# Test with a simple prompt
test_prompt = "Say 'Hello, I am working!' in one sentence."

print("Testing API call with different models...\n")

# Try different models
models_to_try = ["gpt-4o", "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo"]

for model in models_to_try:
    print(f"Trying model: {model}...")
    response, error = call_openai(test_prompt, model=model, fallback_model=None)
    
    if response:
        print(f"✅ Success with {model}! Response: {response}\n")
        break
    else:
        print(f"❌ Failed with {model}: {error}\n")

if response:
    print(f"✅ Success! Response: {response}")
else:
    print(f"❌ Failed: {error}")
    sys.exit(1)

