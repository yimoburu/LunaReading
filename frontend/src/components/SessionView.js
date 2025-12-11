import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import API_URL from '../config';
import Navbar from './Navbar';
import audioService from '../utils/audioService';

const SessionView = () => {
  const { sessionId } = useParams();
  const navigate = useNavigate();
  const [session, setSession] = useState(null);
  const [answers, setAnswers] = useState({});
  const [feedbacks, setFeedbacks] = useState({});
  const [examples, setExamples] = useState({});
  const [submissionStates, setSubmissionStates] = useState({}); // Track if first submission was made
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState({});
  const [error, setError] = useState('');
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isListening, setIsListening] = useState({});
  const speakingQuestionId = useRef(null);

  useEffect(() => {
    fetchSession();
  }, [sessionId]);
  
  useEffect(() => {
    // Set up audio service callbacks
    audioService.onSpeakingStart = () => setIsSpeaking(true);
    audioService.onSpeakingEnd = () => {
      setIsSpeaking(false);
      speakingQuestionId.current = null;
    };
    audioService.onListeningStart = () => {};
    audioService.onListeningEnd = () => {
      setIsListening(prev => {
        const newState = { ...prev };
        if (speakingQuestionId.current !== null) {
          newState[speakingQuestionId.current] = false;
        }
        return newState;
      });
    };
    audioService.onResult = (transcript) => {
      if (speakingQuestionId.current !== null) {
        const questionId = speakingQuestionId.current;
        setAnswers(prev => ({
          ...prev,
          [questionId]: transcript
        }));
        setIsListening(prev => ({
          ...prev,
          [questionId]: false
        }));
      }
    };
    audioService.onError = (error) => {
      console.error('Audio service error:', error);
      setIsListening(prev => {
        const newState = { ...prev };
        if (speakingQuestionId.current !== null) {
          newState[speakingQuestionId.current] = false;
        }
        return newState;
      });
    };
    
    // Cleanup on unmount
    return () => {
      audioService.stopSpeaking();
      audioService.stopListening();
    };
  }, []);

  const fetchSession = async () => {
    try {
      const url = API_URL ? `${API_URL}/api/sessions/${sessionId}` : `/api/sessions/${sessionId}`;
      const response = await axios.get(url);
      setSession(response.data);
      
      // Initialize answers from existing data
      const initialAnswers = {};
      response.data.questions.forEach(q => {
        if (q.answer) {
          initialAnswers[q.id] = q.answer;
        }
      });
      setAnswers(initialAnswers);
      
      // Load feedbacks and examples
      const initialFeedbacks = {};
      const initialExamples = {};
      const initialSubmissionStates = {};
      response.data.questions.forEach(q => {
        if (q.feedback) {
          initialFeedbacks[q.id] = {
            feedback: q.feedback,
            score: q.score,
            rating: q.rating,
            isSufficient: q.score >= 0.7
          };
          initialSubmissionStates[q.id] = true; // Already submitted
        }
      });
      setFeedbacks(initialFeedbacks);
      setExamples(initialExamples);
      setSubmissionStates(initialSubmissionStates);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load session');
    } finally {
      setLoading(false);
    }
  };

  const handleAnswerChange = (questionId, value) => {
    setAnswers({
      ...answers,
      [questionId]: value
    });
  };

  const submitAnswer = async (questionId, submissionType = 'initial') => {
    if (!answers[questionId] || !answers[questionId].trim()) {
      setError('Please provide an answer before submitting');
      return;
    }

    setSubmitting({ ...submitting, [questionId]: true });
    setError('');

    try {
      const url = API_URL ? `${API_URL}/api/questions/${questionId}/answer` : `/api/questions/${questionId}/answer`;
      const response = await axios.post(url, {
        answer_text: answers[questionId],
        submission_type: submissionType
      });

      const feedbackData = {
        feedback: response.data.feedback,
        score: response.data.score,
        rating: response.data.rating,
        isSufficient: response.data.is_sufficient,
        submissionType: response.data.submission_type
      };

      setFeedbacks({
        ...feedbacks,
        [questionId]: feedbackData
      });

      // Store examples if provided (first submission)
      if (response.data.examples && response.data.examples.length > 0) {
        setExamples({
          ...examples,
          [questionId]: response.data.examples
        });
        setSubmissionStates({
          ...submissionStates,
          [questionId]: true // Mark that first submission was made
        });
      }

      // If final submission or sufficient, refresh session
      if (submissionType === 'final' || response.data.is_sufficient) {
        fetchSession();
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to submit answer');
    } finally {
      setSubmitting({ ...submitting, [questionId]: false });
    }
  };

  const getScoreClass = (score) => {
    if (score >= 0.7) return 'score-high';
    if (score >= 0.5) return 'score-medium';
    return 'score-low';
  };

  if (loading) {
    return (
      <div>
        <Navbar />
        <div className="loading">Loading session...</div>
      </div>
    );
  }

  if (!session) {
    return (
      <div>
        <Navbar />
        <div className="container">
          <div className="card">
            <div className="error">Session not found</div>
          </div>
        </div>
      </div>
    );
  }

  const allCompleted = session.questions.every(q => 
    feedbacks[q.id]?.isSufficient || q.score >= 0.7
  );

  return (
    <div>
      <Navbar />
      <div className="container">
        <div className="card">
          <h2 style={{ marginBottom: '10px', color: '#667eea' }}>
            {session.book_title} - {session.chapter}
          </h2>
          <p style={{ color: '#666', marginBottom: '20px' }}>
            {allCompleted ? '✅ All questions completed!' : 'Answer the questions below'}
          </p>
          {error && <div className="error">{error}</div>}
        </div>

        {session.questions.map((question) => {
          const feedback = feedbacks[question.id];
          const questionExamples = examples[question.id] || [];
          const hasFirstSubmission = submissionStates[question.id] || false;
          const isCompleted = feedback?.isSufficient || question.score >= 0.7;
          const showActionButtons = hasFirstSubmission && !isCompleted && feedback?.submissionType === 'initial';

          return (
            <div key={question.id} className="card">
              <div className="question-card">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                  <div className="question-number">
                    Question {question.question_number}
                  </div>
                  <button
                    onClick={() => {
                      if (isSpeaking && speakingQuestionId.current === question.id) {
                        audioService.stopSpeaking();
                      } else {
                        speakingQuestionId.current = question.id;
                        audioService.speak(question.question_text);
                      }
                    }}
                    style={{
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      fontSize: '18px',
                      color: '#667eea',
                      padding: '5px'
                    }}
                    title={isSpeaking && speakingQuestionId.current === question.id ? 'Stop reading' : 'Read question'}
                  >
                    {isSpeaking && speakingQuestionId.current === question.id ? '⏸️' : '🔊'}
                  </button>
                </div>
                <p style={{ fontSize: '18px', marginBottom: '20px' }}>
                  {question.question_text}
                </p>

                {!isCompleted ? (
                  <>
                    <div className="form-group">
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                        <label>Your Answer</label>
                        <button
                          onClick={() => {
                            if (isListening[question.id]) {
                              audioService.stopListening();
                              setIsListening({ ...isListening, [question.id]: false });
                            } else {
                              if (audioService.isSpeechRecognitionAvailable()) {
                                speakingQuestionId.current = question.id;
                                setIsListening({ ...isListening, [question.id]: true });
                                audioService.startListening();
                              } else {
                                alert('Speech recognition is not supported in your browser. Please use Chrome or Edge.');
                              }
                            }
                          }}
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            fontSize: '18px',
                            color: isListening[question.id] ? '#dc3545' : '#667eea',
                            padding: '5px',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '5px'
                          }}
                          disabled={submitting[question.id] || isCompleted}
                          title={isListening[question.id] ? 'Stop listening' : 'Voice input'}
                        >
                          {isListening[question.id] ? '🎤 Listening...' : '🎤'}
                        </button>
                      </div>
                      <textarea
                        value={answers[question.id] || ''}
                        onChange={(e) => handleAnswerChange(question.id, e.target.value)}
                        placeholder="Type your answer here..."
                        disabled={submitting[question.id] || isCompleted}
                      />
                    </div>
                    
                    {!hasFirstSubmission ? (
                      <button
                        onClick={() => submitAnswer(question.id, 'initial')}
                        className="btn btn-primary"
                        disabled={submitting[question.id] || !answers[question.id]?.trim()}
                      >
                        {submitting[question.id] ? 'Submitting...' : 'Submit Answer'}
                      </button>
                    ) : null}
                  </>
                ) : (
                  <div style={{ marginTop: '15px' }}>
                    <div style={{ marginBottom: '15px' }}>
                      <strong>Your Answer:</strong>
                      <p style={{ marginTop: '8px', padding: '10px', background: '#f0f0f0', borderRadius: '4px' }}>
                        {answers[question.id] || question.answer}
                      </p>
                    </div>
                    {feedback && (
                      <>
                        <div style={{ marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '15px' }}>
                          <strong>Score: </strong>
                          <span className={`score-badge ${getScoreClass(feedback.score)}`}>
                            {(feedback.score * 100).toFixed(0)}%
                          </span>
                          {feedback.rating && (
                            <>
                              <strong>Rating: </strong>
                              <span style={{ 
                                fontSize: '18px', 
                                fontWeight: 'bold', 
                                color: '#667eea' 
                              }}>
                                {feedback.rating}/5 ⭐
                              </span>
                            </>
                          )}
                        </div>
                        <div className="feedback-box">
                          <strong>Feedback:</strong>
                          <p style={{ marginTop: '8px' }}>{feedback.feedback}</p>
                        </div>
                      </>
                    )}
                  </div>
                )}

                {/* Show feedback and examples after first submission */}
                    {feedback && !isCompleted && feedback.submissionType === 'initial' && (
                      <div style={{ marginTop: '20px' }}>
                        <div className="feedback-box">
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                            <strong>Feedback:</strong>
                            <button
                              onClick={() => {
                                if (isSpeaking && speakingQuestionId.current === `feedback-${question.id}`) {
                                  audioService.stopSpeaking();
                                } else {
                                  speakingQuestionId.current = `feedback-${question.id}`;
                                  audioService.speak(feedback.feedback);
                                }
                              }}
                              style={{
                                background: 'none',
                                border: 'none',
                                cursor: 'pointer',
                                fontSize: '16px',
                                color: '#667eea',
                                padding: '5px'
                              }}
                              title={isSpeaking && speakingQuestionId.current === `feedback-${question.id}` ? 'Stop reading' : 'Read feedback'}
                            >
                              {isSpeaking && speakingQuestionId.current === `feedback-${question.id}` ? '⏸️' : '🔊'}
                            </button>
                          </div>
                          <p style={{ marginTop: '8px' }}>{feedback.feedback}</p>
                        </div>

                    {questionExamples.length > 0 && (
                      <div style={{ 
                        marginTop: '20px', 
                        padding: '15px', 
                        background: '#f8f9fa', 
                        borderRadius: '8px',
                        border: '1px solid #e0e0e0'
                      }}>
                        <strong style={{ color: '#667eea', display: 'block', marginBottom: '10px' }}>
                          📝 Example Answers (for reference):
                        </strong>
                        {questionExamples.map((example, idx) => (
                          <div 
                            key={idx} 
                            style={{ 
                              marginTop: idx > 0 ? '10px' : '0',
                              padding: '10px',
                              background: 'white',
                              borderRadius: '4px',
                              fontSize: '14px',
                              lineHeight: '1.6'
                            }}
                          >
                            <strong>Example {idx + 1}:</strong> {example}
                          </div>
                        ))}
                        <p style={{ 
                          marginTop: '10px', 
                          fontSize: '12px', 
                          color: '#666',
                          fontStyle: 'italic'
                        }}>
                          Note: The blanks [_____] represent key details you should include in your answer.
                        </p>
                      </div>
                    )}

                    {/* Action buttons */}
                    {showActionButtons && (
                      <div style={{ 
                        marginTop: '20px', 
                        display: 'flex', 
                        gap: '10px',
                        flexWrap: 'wrap'
                      }}>
                        <button
                          onClick={() => submitAnswer(question.id, 'retry')}
                          className="btn btn-secondary"
                          disabled={submitting[question.id] || !answers[question.id]?.trim()}
                          style={{ flex: '1', minWidth: '150px' }}
                        >
                          {submitting[question.id] ? 'Submitting...' : 'Try Again'}
                        </button>
                        <button
                          onClick={() => submitAnswer(question.id, 'final')}
                          className="btn btn-primary"
                          disabled={submitting[question.id] || !answers[question.id]?.trim()}
                          style={{ flex: '1', minWidth: '150px' }}
                        >
                          {submitting[question.id] ? 'Submitting...' : 'Final Submit'}
                        </button>
                      </div>
                    )}

                    {/* Show message after retry or final submit */}
                    {feedback.submissionType === 'retry' && feedback.rating && (
                      <div style={{ 
                        marginTop: '15px', 
                        padding: '10px', 
                        background: '#d4edda', 
                        borderRadius: '4px',
                        color: '#155724'
                      }}>
                        ✅ Great improvement! Your answer received a rating of {feedback.rating}/5.
                      </div>
                    )}
                    {feedback.submissionType === 'final' && feedback.rating && (
                      <div style={{ 
                        marginTop: '15px', 
                        padding: '10px', 
                        background: '#d4edda', 
                        borderRadius: '4px',
                        color: '#155724'
                      }}>
                        ✅ Final answer submitted! Your answer received a rating of {feedback.rating}/5.
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          );
        })}

        {allCompleted && (
          <div className="card">
            <div style={{ textAlign: 'center' }}>
              <h3 style={{ color: '#28a745', marginBottom: '15px' }}>
                🎉 Great job! You've completed all questions!
              </h3>
              <button
                onClick={() => navigate('/history')}
                className="btn btn-primary"
                style={{ marginRight: '10px' }}
              >
                View History
              </button>
              <button
                onClick={() => navigate('/session/create')}
                className="btn btn-secondary"
              >
                Start New Session
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default SessionView;

