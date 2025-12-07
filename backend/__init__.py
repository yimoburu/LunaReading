"""
LunaReading Backend Application Factory

This module creates and configures the Flask application instance.
"""

import traceback
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager

# Initialize extensions (fast, non-blocking)
jwt = JWTManager()

# Lazy imports - only import when needed to speed up startup
# Config and CloudSQLClient will be imported inside create_app() when needed


def create_app():
    """
    Application factory pattern for creating Flask app instance
    
    Returns:
        Flask: Configured Flask application instance
    """
    # Import here to avoid blocking module-level imports
    from backend.config import Config
    from backend.cloudsql_client import CloudSQLClient
    
    app = Flask(__name__)
    
    # Load configuration (non-blocking, just sets config values)
    app.config.from_object(Config)
    
    # Validate config but don't fail if env vars are missing (they'll be set later)
    try:
        Config.validate_database()
    except Exception:
        # Config validation failed, but continue - env vars might be set via Cloud Run
        pass
    
    # Initialize extensions (fast, non-blocking)
    CORS(app)
    jwt.init_app(app)
    
    # Register health check endpoints FIRST - these must work immediately
    # Cloud Run uses these to verify the container started successfully
    @app.route('/health', methods=['GET'])
    def health():
        """Health check endpoint for Cloud Run - must respond quickly"""
        return jsonify({'status': 'healthy'}), 200
    
    @app.route('/', methods=['GET'])
    def index():
        """Health check endpoint - responds immediately, doesn't require database"""
        return jsonify({
            'message': 'LunaReading API Server',
            'status': 'running',
            'database': 'Cloud SQL (MySQL)',
            'database_status': 'not connected'  # Will be updated when DB connects
        }), 200
    
    # Initialize database client (lazy - doesn't block startup)
    app.db_client = None
    
    def init_database():
        """Initialize database client - non-blocking, fails gracefully"""
        # Validate required env vars before attempting connection
        if not Config.CLOUDSQL_INSTANCE_CONNECTION_NAME:
            return False
        if not Config.CLOUDSQL_USER:
            return False
        if not Config.CLOUDSQL_PASSWORD:
            return False
        
        try:
            app.db_client = CloudSQLClient(
                instance_connection_name=Config.CLOUDSQL_INSTANCE_CONNECTION_NAME,
                database=Config.CLOUDSQL_DATABASE,
                user=Config.CLOUDSQL_USER,
                password=Config.CLOUDSQL_PASSWORD
            )
            return True
        except Exception as e:
            # Fail silently during startup - will retry on first use
            app.db_client = None
            return False
    
    # Don't initialize database during app creation - do it lazily on first use
    # This ensures the app starts immediately and listens on the port
    # Database will be initialized when first needed
    
    # Make init function available for retry
    app.init_database = init_database
    
    # Helper function to get database client (with auto-retry)
    def get_db_client():
        """Get database client, initialize if needed"""
        if app.db_client is None:
            # Initialize on first use (lazy initialization)
            init_database()
        return app.db_client
    
    app.get_db_client = get_db_client
    
    # Register blueprints (lazy import to speed up startup)
    from backend.routes import auth, profile, sessions, questions, admin
    
    app.register_blueprint(auth.bp)
    app.register_blueprint(profile.bp)
    app.register_blueprint(sessions.bp)
    app.register_blueprint(questions.bp)
    app.register_blueprint(admin.bp)
    
    # Database status endpoint (lazy - only when needed)
    @app.route('/api/db-status', methods=['GET'])
    def db_status():
        """Check database connection status"""
        import time
        start_time = time.time()
        
        # Get or initialize database client
        db_client = get_db_client()
        
        if not db_client:
            return jsonify({
                'status': 'error',
                'message': 'Database client not initialized',
                'instance': Config.CLOUDSQL_INSTANCE_CONNECTION_NAME or 'not set',
                'database': Config.CLOUDSQL_DATABASE or 'not set',
                'response_time_ms': round((time.time() - start_time) * 1000, 2)
            }), 500
        
        # Test connection with a simple query
        try:
            db_client.get_user_by_username('__test_connection__')
            return jsonify({
                'status': 'connected',
                'message': 'Database connection is working',
                'instance': Config.CLOUDSQL_INSTANCE_CONNECTION_NAME,
                'database': Config.CLOUDSQL_DATABASE,
                'response_time_ms': round((time.time() - start_time) * 1000, 2)
            }), 200
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': f'Database connection test failed: {str(e)}',
                'error_type': type(e).__name__,
                'instance': Config.CLOUDSQL_INSTANCE_CONNECTION_NAME or 'not set',
                'database': Config.CLOUDSQL_DATABASE or 'not set',
                'response_time_ms': round((time.time() - start_time) * 1000, 2)
            }), 500
    
    return app
