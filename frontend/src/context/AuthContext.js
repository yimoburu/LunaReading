import React, { createContext, useState, useContext, useEffect } from 'react';
import axios from 'axios';
import API_URL from '../config';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [token, setToken] = useState(localStorage.getItem('token'));

  useEffect(() => {
    if (token) {
      // Set base URL only if API_URL is not empty (for relative URLs, don't set baseURL)
      if (API_URL) {
        axios.defaults.baseURL = API_URL;
      }
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      fetchProfile();
    } else {
      setLoading(false);
    }
  }, [token]);

  const fetchProfile = async () => {
    try {
      // Use relative URL if API_URL is empty, otherwise use full URL
      const url = API_URL ? `${API_URL}/api/profile` : '/api/profile';
      const response = await axios.get(url);
      setUser(response.data);
    } catch (error) {
      console.error('Failed to fetch profile:', error);
      logout();
    } finally {
      setLoading(false);
    }
  };

  const login = async (username, password) => {
    try {
      const url = API_URL ? `${API_URL}/api/login` : '/api/login';
      const response = await axios.post(url, { username, password });
      const { access_token, user: userData } = response.data;
      setToken(access_token);
      setUser(userData);
      localStorage.setItem('token', access_token);
      axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
      return { success: true };
    } catch (error) {
      console.error('Login error:', error);
      const errorMessage = error.response?.data?.error || 
                          error.message || 
                          'Login failed. Please check your connection and try again.';
      return {
        success: false,
        error: errorMessage
      };
    }
  };

  const register = async (username, email, password, grade_level) => {
    try {
      const url = API_URL ? `${API_URL}/api/register` : '/api/register';
      const response = await axios.post(url, {
        username,
        email,
        password,
        grade_level
      });
      const { access_token, user: userData } = response.data;
      setToken(access_token);
      setUser(userData);
      localStorage.setItem('token', access_token);
      axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
      return { success: true };
    } catch (error) {
      console.error('Registration error:', error);
      const errorMessage = error.response?.data?.error || 
                          error.message || 
                          'Registration failed. Please check your connection and try again.';
      return {
        success: false,
        error: errorMessage
      };
    }
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('token');
    delete axios.defaults.headers.common['Authorization'];
  };

  const value = {
    user,
    login,
    register,
    logout,
    fetchProfile,
    isAuthenticated: !!user,
    loading
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

