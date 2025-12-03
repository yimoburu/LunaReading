import React, { useState, useEffect } from 'react';
import axios from 'axios';
import API_URL from '../config';
import Navbar from './Navbar';
import { useAuth } from '../context/AuthContext';

const Profile = () => {
  const { user: authUser, fetchProfile } = useAuth();
  const [formData, setFormData] = useState({
    grade_level: 3
  });
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (authUser) {
      setFormData({
        grade_level: authUser.grade_level
      });
    }
  }, [authUser]);

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMessage('');

    try {
      const url = API_URL ? `${API_URL}/api/profile` : '/api/profile';
      await axios.put(url, {
        grade_level: parseInt(formData.grade_level)
      });
      setMessage('Profile updated successfully!');
      // Refresh user data
      await fetchProfile();
    } catch (err) {
      setMessage(err.response?.data?.error || 'Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  if (!authUser) {
    return (
      <div>
        <Navbar />
        <div className="loading">Loading profile...</div>
      </div>
    );
  }

  return (
    <div>
      <Navbar />
      <div className="container">
        <div className="card">
          <h2 style={{ marginBottom: '30px', color: '#667eea' }}>Profile Settings</h2>
          
          <div style={{ marginBottom: '30px' }}>
            <p style={{ fontSize: '16px', marginBottom: '10px' }}>
              <strong>Username:</strong> {authUser.username}
            </p>
            <p style={{ fontSize: '16px', marginBottom: '10px' }}>
              <strong>Email:</strong> {authUser.email}
            </p>
            <p style={{ fontSize: '16px', marginBottom: '10px' }}>
              <strong>Current Reading Level:</strong> {authUser.reading_level?.toFixed(1) || '0.0'}
            </p>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label>Grade Level</label>
              <select
                name="grade_level"
                value={formData.grade_level}
                onChange={handleChange}
                required
              >
                <option value={1}>Grade 1</option>
                <option value={2}>Grade 2</option>
                <option value={3}>Grade 3</option>
                <option value={4}>Grade 4</option>
                <option value={5}>Grade 5</option>
                <option value={6}>Grade 6</option>
              </select>
            </div>
            
            {message && (
              <div className={message.includes('success') ? 'success' : 'error'}>
                {message}
              </div>
            )}
            
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Updating...' : 'Update Profile'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Profile;

