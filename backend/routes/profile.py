"""
User profile routes
"""

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.utils import get_db_client

bp = Blueprint('profile', __name__, url_prefix='/api/profile')


@bp.route('', methods=['GET'])
@jwt_required()
def get_profile():
    """Get current user's profile"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    user = db_client.get_user_by_id(user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    return jsonify({
        'id': user['id'],
        'username': user['username'],
        'email': user['email'],
        'grade_level': user['grade_level'],
        'reading_level': user['reading_level']
    }), 200


@bp.route('', methods=['PUT'])
@jwt_required()
def update_profile():
    """Update current user's profile"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    user = db_client.get_user_by_id(user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    data = request.json
    update_data = {}
    if 'grade_level' in data:
        update_data['grade_level'] = data['grade_level']
    
    if update_data:
        db_client.update_user(user_id, **update_data)
        user = db_client.get_user_by_id(user_id)
    
    return jsonify({
        'message': 'Profile updated successfully',
        'user': {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'grade_level': user['grade_level'],
            'reading_level': user['reading_level']
        }
    }), 200

