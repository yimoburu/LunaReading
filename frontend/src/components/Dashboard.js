import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import Navbar from './Navbar';

const Dashboard = () => {
  const { user } = useAuth();

  return (
    <div>
      <Navbar />
      <div className="container">
        <div className="card">
          <h2 style={{ marginBottom: '20px', color: '#667eea' }}>Welcome, {user?.username}!</h2>
          <p style={{ fontSize: '18px', marginBottom: '10px' }}>
            <strong>Grade Level:</strong> {user?.grade_level}
          </p>
          <p style={{ fontSize: '18px', marginBottom: '30px' }}>
            <strong>Reading Level:</strong> {user?.reading_level?.toFixed(1) || '0.0'}
          </p>
          
          <div style={{ display: 'flex', gap: '15px', flexWrap: 'wrap' }}>
            <Link to="/session/create" className="btn btn-primary">
              Start New Reading Session
            </Link>
            <Link to="/history" className="btn btn-secondary">
              View History
            </Link>
            <Link to="/profile" className="btn btn-secondary">
              Edit Profile
            </Link>
          </div>
        </div>

        <div className="card">
          <h3 style={{ marginBottom: '15px', color: '#333' }}>How It Works</h3>
          <ol style={{ lineHeight: '2', paddingLeft: '20px' }}>
            <li>Create a new reading session by specifying a book and chapter</li>
            <li>Answer the comprehension questions generated for you</li>
            <li>Receive feedback and refine your answers until they meet the standard</li>
            <li>Track your progress and see your reading level improve over time</li>
          </ol>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;

