#!/usr/bin/env python3
"""Script to check registered users with detailed statistics"""
import sys
sys.path.insert(0, 'backend')

from app import app, db, User, ReadingSession, Question, Answer
from datetime import datetime

with app.app_context():
    users = User.query.order_by(User.created_at).all()
    
    print(f"\n📊 Total Users Registered: {len(users)}\n")
    
    if len(users) == 0:
        print("No users registered yet.")
    else:
        print("=" * 150)
        print(f"{'ID':<5} {'Username':<20} {'Email':<30} {'Password Hash':<50} {'Grade':<8} {'Reading':<10} {'Sessions':<10} {'Questions':<12} {'Avg Score':<12} {'Created':<20}")
        print("=" * 150)
        
        for user in users:
            # Count sessions
            sessions = ReadingSession.query.filter_by(user_id=user.id).all()
            session_count = len(sessions)
            
            # Count questions and calculate average score
            total_questions = 0
            total_score = 0.0
            scored_questions = 0
            
            for session in sessions:
                for question in session.questions:
                    total_questions += 1
                    # Get the final answer (is_final=True) for each question
                    final_answer = Answer.query.filter_by(
                        question_id=question.id,
                        is_final=True
                    ).first()
                    if final_answer and final_answer.score is not None:
                        total_score += final_answer.score
                        scored_questions += 1
            
            avg_score = (total_score / scored_questions * 100) if scored_questions > 0 else 0.0
            avg_score_str = f"{avg_score:.1f}%" if scored_questions > 0 else "N/A"
            
            created_str = user.created_at.strftime('%Y-%m-%d %H:%M') if user.created_at else 'N/A'
            reading_level_str = f"{user.reading_level:.2f}" if user.reading_level else "0.00"
            password_hash = user.password_hash[:47] + "..." if len(user.password_hash) > 50 else user.password_hash
            
            print(f"{user.id:<5} {user.username:<20} {user.email:<30} {password_hash:<50} {user.grade_level:<8} {reading_level_str:<10} {session_count:<10} {total_questions:<12} {avg_score_str:<12} {created_str:<20}")
        
        print("=" * 150)
        print(f"\nTotal: {len(users)} user(s)")
        
        # Summary statistics
        total_sessions = ReadingSession.query.count()
        total_questions = Question.query.count()
        completed_sessions = ReadingSession.query.filter(ReadingSession.completed_at.isnot(None)).count()
        
        print(f"\n📈 Overall Statistics:")
        print(f"   Total Sessions: {total_sessions}")
        print(f"   Completed Sessions: {completed_sessions}")
        print(f"   Total Questions: {total_questions}")

