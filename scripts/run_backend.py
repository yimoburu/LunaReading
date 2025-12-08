#!/usr/bin/env python3
"""
Simple script to run the backend server from project root

Usage:
    python run_backend.py
"""

import sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# Now import and run
from backend.app import app

if __name__ == '__main__':
    import os
    
    # Initialize database
    try:
        print("Initializing database...")
        from backend import db
        with app.app_context():
            db.create_all()
        print("✅ Database initialized successfully")
    except Exception as e:
        print(f"⚠️  Warning: Database initialization error: {e}")
    
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
        import traceback
        traceback.print_exc()
        raise

