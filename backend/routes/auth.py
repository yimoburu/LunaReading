"""
Authentication routes for user registration and login
"""

import os
import traceback
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash, check_password_hash
from backend.utils import get_db_client

bp = Blueprint('auth', __name__, url_prefix='/api')


@bp.route('/register', methods=['POST'])
def register():
    """Register a new user"""
    try:
        # Get database client (with auto-retry)
        db_client = get_db_client(current_app)
        
        if not db_client:
            error_msg = (
                'Database connection failed. '
                'Please verify:\n'
                '1. Cloud SQL instance is added to Cloud Run service (--add-cloudsql-instances)\n'
                '2. Service account has roles/cloudsql.client permission\n'
                '3. Environment variables are set correctly (CLOUDSQL_INSTANCE_CONNECTION_NAME, CLOUDSQL_USER, CLOUDSQL_PASSWORD, CLOUDSQL_DATABASE)'
            )
            return jsonify({'error': error_msg}), 500
        
        if not request.json:
            return jsonify({'error': 'Request body must be JSON'}), 400
        
        data = request.json
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        grade_level = data.get('grade_level')
        print(f"Registering user: {username}, {email}, {password}, {grade_level}")
        print(f"Request body: {request.json}")
        
        if not all([username, email, password, grade_level]):
            return jsonify({'error': 'All fields are required'}), 400
        
        # Check for existing user
        print(f"Checking for existing users: {username}, {email}")
        try:
            if db_client.get_user_by_username(username):
                return jsonify({'error': 'Username already exists'}), 400
            
            if db_client.get_user_by_email(email):
                return jsonify({'error': 'Email already exists'}), 400
        except Exception as db_check_error:
            print(f"Error checking existing users: {db_check_error}")
            traceback.print_exc()
            return jsonify({
                'error': f'Database error: {str(db_check_error)}. Please check Cloud SQL connection.'
            }), 500
        
        # Create new user
        print(f"Creating new user: {username}, {email}, {password}, {grade_level}")
        try:
            password_hash = generate_password_hash(password, method='pbkdf2:sha256')
            reading_level = grade_level * 0.8  # Initial estimate
            user_id = db_client.insert_user(username, email, password_hash, grade_level, reading_level)
            
            # Get created user
            user = db_client.get_user_by_id(user_id)
            if not user:
                return jsonify({'error': 'Failed to retrieve created user'}), 500
        except Exception as db_insert_error:
            print(f"Error inserting user: {db_insert_error}")
            traceback.print_exc()
            return jsonify({
                'error': f'Failed to create user: {str(db_insert_error)}. Please check database connection and permissions.'
            }), 500
        
        access_token = create_access_token(identity=str(user_id))
        return jsonify({
            'message': 'User created successfully',
            'access_token': access_token,
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'grade_level': user['grade_level'],
                'reading_level': user['reading_level']
            }
        }), 201
    except Exception as e:
        error_msg = str(e)
        print(f"Registration error: {error_msg}")
        traceback.print_exc()
        if os.environ.get('FLASK_DEBUG') == 'True':
            return jsonify({'error': f'Registration failed: {error_msg}'}), 500
        else:
            return jsonify({'error': 'Registration failed. Please try again.'}), 500


@bp.route('/login', methods=['POST'])
def login():
    """Login and get access token"""
    db_client = get_db_client(current_app)
    print("login")
    print(f"db_client: {db_client}")
    print(f"current_app: {current_app}")
    print(f"request: {request}")
    print(f"request.json: {request.json}")
    print(f"request.args: {request.args}")
    print(f"request.form: {request.form}")
    print(f"request.files: {request.files}")
    print(f"request.headers: {request.headers}")
    print(f"request.url: {request.url}")
    print(f"request.base_url: {request.base_url}")

    if not db_client:
        return jsonify({'error': 'Database connection not available'}), 500
    
    data = request.json
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password are required'}), 400
        
    user = db_client.get_user_by_username(username)

    print(f"DBDEBUG: user: {user}")
    
    if not user or not check_password_hash(user['password_hash'], password):
        return jsonify({'error': 'Invalid credentials'}), 401
    
    access_token = create_access_token(identity=str(user['id']))
    return jsonify({
        'access_token': access_token,
        'user': {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'grade_level': user['grade_level'],
            'reading_level': user['reading_level']
        }
    }), 200

