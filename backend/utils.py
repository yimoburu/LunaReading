"""
Utility functions for LunaReading backend
"""

import os
import json
import traceback
from dotenv import load_dotenv
from openai import OpenAI
import openai
from backend.config import Config


def get_openai_client():
    """Get OpenAI client instance"""
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key or api_key == 'your-openai-api-key-here':
        return None
    return OpenAI(api_key=api_key)


def clean_json_response(response_text):
    """Clean JSON response from LLM and return cleaned string"""
    # Remove markdown code blocks if present
    response_text = response_text.strip()
    if response_text.startswith('```json'):
        response_text = response_text[7:]
    elif response_text.startswith('```'):
        response_text = response_text[3:]
    if response_text.endswith('```'):
        response_text = response_text[:-3]
    response_text = response_text.strip()
    
    # Try to extract JSON from the response if it's not valid JSON
    try:
        # Validate it's valid JSON by parsing it
        json.loads(response_text)
        return response_text
    except json.JSONDecodeError:
        # Try to extract JSON from the response
        try:
            # Find first { or [
            start = response_text.find('{')
            if start == -1:
                start = response_text.find('[')
            if start != -1:
                # Find matching closing bracket
                bracket_count = 0
                for i in range(start, len(response_text)):
                    if response_text[i] in ['{', '[']:
                        bracket_count += 1
                    elif response_text[i] in ['}', ']']:
                        bracket_count -= 1
                        if bracket_count == 0:
                            # Validate extracted JSON
                            json.loads(response_text[start:i+1])
                            return response_text[start:i+1]
        except json.JSONDecodeError:
            pass
        raise json.JSONDecodeError("Invalid JSON in LLM response", response_text, 0)


def call_openai(prompt, model="gpt-4o", temperature=0.7, fallback_model="gpt-3.5-turbo"):
    """
    Call OpenAI API with error handling and fallback model support
    
    Returns:
        tuple: (response_text, error_message)
    """
    client = get_openai_client()
    if not client:
        return None, "OpenAI API key not configured"
    
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=temperature
        )
        return response.choices[0].message.content, None
    except openai.RateLimitError:
        # Try fallback model if rate limited
        if fallback_model and fallback_model != model:
            try:
                print(f"Rate limited on {model}, trying {fallback_model}...")
                response = client.chat.completions.create(
                    model=fallback_model,
                    messages=[
                        {"role": "system", "content": "You are a helpful assistant."},
                        {"role": "user", "content": prompt}
                    ],
                    temperature=temperature
                )
                return response.choices[0].message.content, None
            except Exception as e:
                return None, f"Fallback model also failed: {str(e)}"
        return None, "Rate limit exceeded"
    except Exception as e:
        return None, f"OpenAI API error: {str(e)}"


def get_db_client(app):
    """
    Get database client from Flask app with auto-retry
    
    Args:
        app: Flask application instance (current_app)
    
    Returns:
        CloudSQLClient or None
    """
    if hasattr(app, 'get_db_client'):
        return app.get_db_client()
    return app.db_client if hasattr(app, 'db_client') else None


def require_db_client(app):
    """
    Get database client or raise error response
    
    Args:
        app: Flask application instance (current_app)
    
    Returns:
        tuple: (db_client, error_response) where error_response is None if successful
    """
    from flask import jsonify
    
    db_client = get_db_client(app)
    if not db_client:
        error_msg = (
            'Database connection not available. '
            'Please verify Cloud SQL configuration and ensure the instance is added to Cloud Run service.'
        )
        return None, (jsonify({'error': error_msg}), 500)
    return db_client, None
