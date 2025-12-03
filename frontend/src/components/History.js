import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import API_URL from '../config';
import Navbar from './Navbar';

const History = () => {
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchSessions();
  }, []);

  const fetchSessions = async () => {
    try {
      const url = API_URL ? `${API_URL}/api/sessions` : '/api/sessions';
      const response = await axios.get(url);
      setSessions(response.data);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load history');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  if (loading) {
    return (
      <div>
        <Navbar />
        <div className="loading">Loading history...</div>
      </div>
    );
  }

  return (
    <div>
      <Navbar />
      <div className="container">
        <div className="card">
          <h2 style={{ marginBottom: '30px', color: '#667eea' }}>Reading History</h2>
          
          {error && <div className="error">{error}</div>}
          
          {sessions.length === 0 ? (
            <p style={{ textAlign: 'center', color: '#666', fontSize: '18px' }}>
              No reading sessions yet. <Link to="/session/create" style={{ color: '#667eea' }}>Start your first session!</Link>
            </p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
              {sessions.map((session) => (
                <div
                  key={session.id}
                  style={{
                    padding: '20px',
                    border: '2px solid #e0e0e0',
                    borderRadius: '8px',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    flexWrap: 'wrap',
                    gap: '15px'
                  }}
                >
                  <div style={{ flex: 1 }}>
                    <h3 style={{ marginBottom: '8px', color: '#333' }}>
                      {session.book_title} - {session.chapter}
                    </h3>
                    <p style={{ color: '#666', marginBottom: '5px' }}>
                      Created: {formatDate(session.created_at)}
                    </p>
                    <p style={{ color: '#666' }}>
                      Progress: {session.completed_questions} / {session.total_questions} questions
                    </p>
                  </div>
                  <Link
                    to={`/session/${session.id}`}
                    className="btn btn-primary"
                    style={{ textDecoration: 'none' }}
                  >
                    {session.completed_questions === session.total_questions ? 'View' : 'Continue'}
                  </Link>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default History;

