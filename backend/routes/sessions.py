"""
Reading session routes
"""

import json
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.utils import call_openai, clean_json_response, get_db_client

bp = Blueprint('sessions', __name__, url_prefix='/api/sessions')


@bp.route('', methods=['POST'])
@jwt_required()
def create_session():
    """Create a new reading session with AI-generated questions"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    user = db_client.get_user_by_id(user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    data = request.json
    book_title = data.get('book_title')
    chapter = data.get('chapter')
    total_questions = data.get('total_questions', 5)
    
    if not all([book_title, chapter]):
        return jsonify({'error': 'Book title and chapter are required'}), 400
    
    # Create session
    session_id = db_client.insert_session(user_id, book_title, chapter, total_questions)
    
    # Generate questions using LLM
    reading_level = user['reading_level'] or (user['grade_level'] * 0.8)
    
    prompt = f"""You are an expert reading comprehension teacher for elementary students.

Student Information:
- Grade Level: {user['grade_level']}
- Current Reading Level: {reading_level:.1f}
- Book: {book_title}
- Chapter: {chapter}

Generate {total_questions} reading comprehension questions that are:
1. Slightly above the student's current reading level (to challenge them appropriately)
2. Based on the specified book and chapter
3. Appropriate for elementary students
4. Include a mix of question types (literal, inferential, evaluative)

For each question, provide:
- The question text
- A model answer (what a good answer should include)

Format your response as a JSON array with this structure:
[
  {{
    "question_number": 1,
    "question_text": "...",
    "model_answer": "..."
  }},
  ...
]

Return ONLY the JSON array, no additional text."""

    # Generate questions
    llm_response, error_msg = call_openai(prompt, model="gpt-4o", temperature=0.7, fallback_model="gpt-3.5-turbo")
    
    if not llm_response:
        error_message = error_msg if error_msg else 'Failed to generate questions. Please try again.'
        return jsonify({'error': error_message}), 500
    
    try:
        # Parse and create questions
        llm_response = clean_json_response(llm_response)
        questions_data = json.loads(llm_response)
        
        question_ids = []
        for q_data in questions_data:
            question_id = db_client.insert_question(
                session_id=session_id,
                question_text=q_data.get('question_text', ''),
                question_number=q_data.get('question_number', len(question_ids) + 1),
                model_answer=q_data.get('model_answer', '')
            )
            question_ids.append(question_id)
        
        # Get session and questions for response
        session = db_client.get_session_by_id(session_id)
        questions = db_client.get_questions_by_session(session_id)
        
        # Return session with questions
        session_data = {
            'id': session['id'],
            'book_title': session['book_title'],
            'chapter': session['chapter'],
            'total_questions': session['total_questions'],
            'created_at': session['created_at'].isoformat() if session['created_at'] else None,
            'questions': [
                {
                    'id': q['id'],
                    'question_number': q['question_number'],
                    'question_text': q['question_text']
                }
                for q in questions
            ]
        }
        
        return jsonify(session_data), 201
        
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        current_app.logger.error(f"Failed to parse LLM response: {str(e)}")
        return jsonify({'error': f'Failed to parse generated questions: {str(e)}'}), 500


@bp.route('', methods=['GET'])
@jwt_required()
def get_sessions():
    """Get all reading sessions for current user"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    sessions = db_client.get_sessions_by_user(user_id)
    
    sessions_data = []
    for session in sessions:
        stats = db_client.get_session_statistics(session['id'])
        sessions_data.append({
            'id': session['id'],
            'book_title': session['book_title'],
            'chapter': session['chapter'],
            'total_questions': session['total_questions'],
            'completed_questions': stats['completed_questions'],
            'created_at': session['created_at'].isoformat() if session['created_at'] else None,
            'completed_at': session['completed_at'].isoformat() if session['completed_at'] else None
        })
    
    return jsonify(sessions_data), 200


@bp.route('/<int:session_id>', methods=['GET'])
@jwt_required()
def get_session(session_id):
    """Get a specific reading session with questions and answers"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    session = db_client.get_session_by_id(session_id, user_id)
    
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    
    questions = db_client.get_questions_by_session(session_id)
    questions_data = []
    for q in questions:
        final_answer = db_client.get_final_answer_by_question(q['id'])
        first_answer = db_client.get_initial_answer_by_question(q['id'])
        
        # Safely parse examples JSON
        examples = None
        if first_answer and first_answer.get('examples'):
            try:
                examples = json.loads(first_answer['examples'])
            except (json.JSONDecodeError, TypeError) as e:
                current_app.logger.warning(f"Failed to parse examples JSON for question {q['id']}: {str(e)}")
                examples = None
        
        questions_data.append({
            'id': q['id'],
            'question_number': q['question_number'],
            'question_text': q['question_text'],
            'answer': final_answer['answer_text'] if final_answer else None,
            'score': final_answer['score'] if final_answer else None,
            'rating': final_answer['rating'] if final_answer else None,
            'feedback': final_answer['feedback'] if final_answer else None,
            'examples': examples
        })
    
    session_data = {
        'id': session['id'],
        'book_title': session['book_title'],
        'chapter': session['chapter'],
        'total_questions': session['total_questions'],
        'created_at': session['created_at'].isoformat() if session['created_at'] else None,
        'questions': questions_data
    }
    
    return jsonify(session_data), 200

