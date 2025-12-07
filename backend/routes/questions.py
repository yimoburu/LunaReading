"""
Question and answer routes
"""

import json
from datetime import datetime
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.utils import call_openai, clean_json_response, get_db_client

bp = Blueprint('questions', __name__, url_prefix='/api/questions')


def _build_initial_evaluation_prompt(question, answer_text):
    """Build prompt for initial answer evaluation"""
    return f"""You are an expert reading comprehension teacher evaluating a student's answer.

Question: {question['question_text']}

Model Answer (what a good answer should include): {question.get('model_answer', '')}

Student's Answer: {answer_text}

Evaluate the student's answer and provide:
1. A score from 0.0 to 1.0 (where 1.0 is excellent and matches the model answer well)
2. Constructive feedback that:
   - Points out what the student did well
   - Identifies what's missing or could be improved
   - Provides specific guidance on how to improve
   - Encourages the student
3. Two example answers (based on the model answer) with key details replaced by blanks [_____] for the student's reference.
   The examples should show the structure and key points, but leave specific details as blanks so the student can fill them in.

Format your response as JSON:
{{
  "score": 0.85,
  "feedback": "Your answer shows good understanding of... However, you could improve by...",
  "examples": [
    "Example 1: The main character [_____] because [_____]. This shows that [_____].",
    "Example 2: According to the text, [_____] happened when [_____]. This is important because [_____]."
  ]
}}

Return ONLY the JSON object, no additional text."""


def _build_retry_evaluation_prompt(question, answer_text):
    """Build prompt for retry answer evaluation"""
    return f"""You are an expert reading comprehension teacher evaluating a student's revised answer.

Question: {question['question_text']}

Model Answer (what a good answer should include): {question.get('model_answer', '')}

Student's Revised Answer: {answer_text}

Evaluate the student's revised answer and provide:
1. A score from 0.0 to 1.0 (where 1.0 is excellent and matches the model answer well)
2. Constructive feedback that:
   - Points out what the student improved
   - Identifies what's still missing or could be improved
   - Provides specific guidance on how to improve further
   - Encourages the student
3. A rating from 1 to 5 (where 5 is the highest) - ONLY provide a rating if the score is 0.7 or higher.
   If the score is below 0.7, set rating to null.

Format your response as JSON:
{{
  "score": 0.85,
  "feedback": "Great improvement! You now mention... However, you could still improve by...",
  "rating": 4,
  "is_sufficient": true or false
}}

"is_sufficient" should be true if the score is 0.7 or higher, false otherwise.
"rating" should be null if score < 0.7, otherwise a number from 1-5.

Return ONLY the JSON object, no additional text."""


def _build_final_evaluation_prompt(question, answer_text):
    """Build prompt for final answer evaluation"""
    return f"""You are an expert reading comprehension teacher evaluating a student's final answer.

Question: {question['question_text']}

Model Answer (what a good answer should include): {question.get('model_answer', '')}

Student's Final Answer: {answer_text}

Evaluate the student's final answer and provide:
1. A score from 0.0 to 1.0 (where 1.0 is excellent and matches the model answer well)
2. Constructive feedback that:
   - Points out what the student did well
   - Identifies what could still be improved (if any)
   - Provides encouragement
3. A rating from 1 to 5 (where 5 is the highest) based on the overall quality of the answer.

Format your response as JSON:
{{
  "score": 0.85,
  "feedback": "Your final answer demonstrates good understanding of...",
  "rating": 4,
  "is_sufficient": true
}}

"is_sufficient" should be true if the score is 0.7 or higher, false otherwise.
"rating" should always be a number from 1-5.

Return ONLY the JSON object, no additional text."""


@bp.route('/<int:question_id>/answer', methods=['POST'])
@jwt_required()
def submit_answer(question_id):
    """Submit an answer to a question and get AI evaluation"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    question = db_client.get_question_by_id(question_id)
    
    if not question:
        return jsonify({'error': 'Question not found'}), 404
    
    # Verify the question belongs to the user
    session = db_client.get_session_by_id(question['session_id'])
    if not session or session['user_id'] != user_id:
        return jsonify({'error': 'Unauthorized'}), 403
    
    data = request.json
    answer_text = data.get('answer_text')
    submission_type = data.get('submission_type', 'initial')
    
    if not answer_text:
        return jsonify({'error': 'Answer text is required'}), 400
    
    # Check if this is the first submission
    existing_answers = db_client.get_answers_by_question(question_id)
    is_first_submission = len(existing_answers) == 0
    
    # Build evaluation prompt based on submission type
    if submission_type == 'initial' and is_first_submission:
        prompt = _build_initial_evaluation_prompt(question, answer_text)
    elif submission_type == 'retry':
        prompt = _build_retry_evaluation_prompt(question, answer_text)
    else:  # submission_type == 'final'
        prompt = _build_final_evaluation_prompt(question, answer_text)
    
    # Evaluate answer
    llm_response, error_msg = call_openai(prompt, model="gpt-4o", temperature=0.3, fallback_model="gpt-3.5-turbo")
    
    if not llm_response:
        error_message = error_msg if error_msg else 'Failed to evaluate answer. Please try again.'
        return jsonify({'error': error_message}), 500
    
    try:
        # Parse evaluation
        llm_response = clean_json_response(llm_response)
        evaluation = json.loads(llm_response)
        score = float(evaluation.get('score', 0.0))
        feedback = evaluation.get('feedback', '')
        examples = evaluation.get('examples', [])
        rating = evaluation.get('rating')
        is_sufficient = evaluation.get('is_sufficient', score >= 0.7)
        
        # Determine if this is final answer
        if submission_type == 'final':
            is_final = True
        elif submission_type == 'retry':
            is_final = is_sufficient
        else:
            is_final = False
        
        # Create answer record
        answer_id = db_client.insert_answer(
            question_id=question_id,
            answer_text=answer_text,
            feedback=feedback,
            score=score,
            rating=rating,
            examples=json.dumps(examples) if examples else None,
            is_final=is_final,
            submission_type=submission_type
        )
        
        # Check if session is completed
        if is_final:
            session = db_client.get_session_by_id(question['session_id'])
            if db_client.check_session_completed(session['id']) and not session['completed_at']:
                db_client.update_session(session['id'], completed_at=datetime.utcnow().isoformat())
                user = db_client.get_user_by_id(user_id)
                # Update user reading level
                avg_score = db_client.get_session_avg_score(session['id'])
                if avg_score:
                    if avg_score >= 0.8:
                        new_reading_level = min(user['reading_level'] + 0.1, user['grade_level'] * 1.2)
                    elif avg_score >= 0.6:
                        new_reading_level = min(user['reading_level'] + 0.05, user['grade_level'] * 1.1)
                    elif avg_score < 0.5:
                        new_reading_level = max(user['reading_level'] - 0.05, user['grade_level'] * 0.7)
                    else:
                        new_reading_level = user['reading_level']
                    db_client.update_user(user_id, reading_level=new_reading_level)
        
        # Build response
        response_data = {
            'answer_id': answer_id,
            'score': score,
            'feedback': feedback,
            'is_sufficient': is_sufficient,
            'submission_type': submission_type
        }
        
        if submission_type == 'initial' and examples:
            response_data['examples'] = examples
            response_data['message'] = 'Review the feedback and examples below, then refine your answer.'
        elif submission_type == 'retry':
            if rating is not None:
                response_data['rating'] = rating
                response_data['message'] = f'Great improvement! Your answer received a rating of {rating}/5.'
            else:
                response_data['message'] = 'Please continue refining your answer based on the feedback.'
        elif submission_type == 'final':
            response_data['rating'] = rating
            response_data['message'] = f'Final answer submitted! Your answer received a rating of {rating}/5.'
        
        return jsonify(response_data), 200
        
    except (json.JSONDecodeError, TypeError, ValueError, KeyError) as e:
        current_app.logger.error(f"Failed to parse LLM evaluation response: {str(e)}")
        return jsonify({'error': f'Failed to parse evaluation: {str(e)}'}), 500


@bp.route('/<int:question_id>/answers', methods=['GET'])
@jwt_required()
def get_answers(question_id):
    """Get all answers for a question"""
    db_client = get_db_client(current_app)
    user_id = int(get_jwt_identity())
    question = db_client.get_question_by_id(question_id)
    
    if not question:
        return jsonify({'error': 'Question not found'}), 404
    
    session = db_client.get_session_by_id(question['session_id'])
    if not session or session['user_id'] != user_id:
        return jsonify({'error': 'Unauthorized'}), 403
    
    answers = db_client.get_answers_by_question(question_id)
    
    answers_data = []
    for a in answers:
        # Safely parse examples JSON
        examples = None
        if a.get('examples'):
            try:
                examples = json.loads(a['examples'])
            except (json.JSONDecodeError, TypeError) as e:
                current_app.logger.warning(f"Failed to parse examples JSON for answer {a['id']}: {str(e)}")
                examples = None
        
        answers_data.append({
            'id': a['id'],
            'answer_text': a['answer_text'],
            'feedback': a['feedback'],
            'score': a['score'],
            'rating': a['rating'],
            'examples': examples,
            'is_final': a['is_final'],
            'submission_type': a['submission_type'],
            'created_at': a['created_at'].isoformat() if a['created_at'] else None
        })
    
    return jsonify(answers_data), 200

