import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import API_URL from '../config';
import Navbar from './Navbar';

const SessionCreate = () => {
  const [formData, setFormData] = useState({
    book_title: '',
    chapter: '',
    total_questions: 5
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const url = API_URL ? `${API_URL}/api/sessions` : '/api/sessions';
      const response = await axios.post(url, {
        book_title: formData.book_title,
        chapter: formData.chapter,
        total_questions: parseInt(formData.total_questions)
      });

      navigate(`/session/${response.data.id}`);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to create session');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <Navbar />
      <div className="container">
        <div className="card">
          <h2 style={{ marginBottom: '30px', color: '#667eea' }}>Create New Reading Session</h2>
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label>Book Title</label>
              <input
                type="text"
                name="book_title"
                value={formData.book_title}
                onChange={handleChange}
                required
                placeholder="e.g., Charlotte's Web"
              />
            </div>
            <div className="form-group">
              <label>Chapter</label>
              <input
                type="text"
                name="chapter"
                value={formData.chapter}
                onChange={handleChange}
                required
                placeholder="e.g., Chapter 1 or Chapter 2: The Escape"
              />
            </div>
            <div className="form-group">
              <label>Number of Questions</label>
              <select
                name="total_questions"
                value={formData.total_questions}
                onChange={handleChange}
                required
              >
                <option value={3}>3 Questions</option>
                <option value={5}>5 Questions</option>
                <option value={7}>7 Questions</option>
                <option value={10}>10 Questions</option>
              </select>
            </div>
            {error && <div className="error">{error}</div>}
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Generating Questions...' : 'Create Session'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default SessionCreate;

