"""
Admin routes for user management and statistics
"""

from flask import Blueprint, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.utils import get_db_client

bp = Blueprint('admin', __name__, url_prefix='/api/admin')


@bp.route('/users', methods=['GET'])
@jwt_required()
def get_all_users():
    """Admin endpoint to view all users with statistics"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    current_user = db_client.get_user_by_id(user_id)
    
    if not current_user:
        return jsonify({'error': 'User not found'}), 404
    
    # For now, allow any authenticated user to view users
    # In production, you might want to add an admin role check
    
    users = db_client.get_all_users()
    
    users_data = []
    for user in users:
        stats = db_client.get_user_session_stats(user['id'])
        
        users_data.append({
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'password_hash': user['password_hash'],
            'grade_level': user['grade_level'],
            'reading_level': user['reading_level'],
            'created_at': user['created_at'].isoformat() if user['created_at'] else None,
            'statistics': {
                'total_sessions': stats['total_sessions'],
                'completed_sessions': stats['completed_sessions'],
                'total_questions': stats['total_questions'],
                'average_score': round(stats['average_score'] * 100, 2) if stats['average_score'] else None
            }
        })
    
    return jsonify({
        'total_users': len(users_data),
        'users': users_data
    }), 200

