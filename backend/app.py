"""
LunaReading Backend API Server - Main Entry Point

This is the main entry point for running the Flask application.
For production deployment, use gunicorn: gunicorn backend.app:app
"""

import os
import sys
import traceback
from pathlib import Path

# Add project root to Python path when running directly
# This allows imports to work both when run directly and as a module
project_root = Path(__file__).parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# Create Flask app instance
# Wrap in try-except to ensure app is created even if there are import issues
try:
    from backend import create_app
    app = create_app()
except Exception as e:
    # If app creation fails, create a minimal app that at least responds
    from flask import Flask, jsonify
    app = Flask(__name__)
    
    @app.route('/', methods=['GET'])
    def index():
        return jsonify({
            'message': 'LunaReading API Server',
            'status': 'error',
            'error': f'App initialization failed: {str(e)}'
        }), 500
    
    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500
    
    # Log the error but don't crash
    print(f"⚠️  App initialization error: {e}", file=sys.stderr)
    traceback.print_exc()

if __name__ == '__main__':
    # Cloud SQL is initialized in create_app()
    # Tables are created automatically if they don't exist
    
    # Get configuration
    port = int(os.environ.get('PORT', 5001))
    host = '0.0.0.0' if os.environ.get('PORT') else os.environ.get('HOST', '127.0.0.1')
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true' and not os.environ.get('PORT')
    
    print(f"Starting Flask server...")
    print(f"Host: {host}, Port: {port}, Debug: {debug}")
    print(f"OpenAI API Key configured: {'Yes' if os.getenv('OPENAI_API_KEY') and os.getenv('OPENAI_API_KEY') != 'your-openai-api-key-here' else 'No'}")
    
    try:
        app.run(host=host, port=port, debug=debug, threaded=True)
    except Exception as e:
        print(f"Fatal error starting server: {e}")
        traceback.print_exc()
        raise
