import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const Navbar = () => {
  const { logout, user } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <nav className="navbar">
      <Link to="/dashboard" style={{ textDecoration: 'none' }}>
        <h1>📚 LunaReading</h1>
      </Link>
      <div className="navbar-links">
        <Link to="/dashboard">Dashboard</Link>
        <Link to="/session/create">New Session</Link>
        <Link to="/history">History</Link>
        <Link to="/profile">Profile</Link>
        <span style={{ color: '#667eea', fontWeight: '600' }}>{user?.username}</span>
        <button onClick={handleLogout} className="btn btn-danger" style={{ padding: '8px 16px', fontSize: '14px' }}>
          Logout
        </button>
      </div>
    </nav>
  );
};

export default Navbar;

