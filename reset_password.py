#!/usr/bin/env python3
"""Script to reset a user's password"""
import sys
sys.path.insert(0, 'backend')

from app import app, db, User
from werkzeug.security import generate_password_hash

def reset_password(username, new_password):
    with app.app_context():
        user = User.query.filter_by(username=username).first()
        
        if not user:
            print(f"❌ User '{username}' not found!")
            return False
        
        # Update password
        user.password_hash = generate_password_hash(new_password, method='pbkdf2:sha256')
        db.session.commit()
        
        print(f"✅ Password reset successfully for user '{username}'")
        print(f"   New password: {new_password}")
        print(f"   Email: {user.email}")
        return True

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python reset_password.py <username> <new_password>")
        print("\nExample: python reset_password.py testuser newpassword123")
        sys.exit(1)
    
    username = sys.argv[1]
    new_password = sys.argv[2]
    
    if len(new_password) < 6:
        print("❌ Password must be at least 6 characters long!")
        sys.exit(1)
    
    reset_password(username, new_password)

