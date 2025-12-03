// API configuration
// Priority:
// 1. Environment variable (set at build time via REACT_APP_API_URL)
// 2. window.REACT_APP_API_URL (injected at runtime via script tag)
// 3. Relative path (for same-origin or nginx proxy) - use empty string
// 4. Default localhost (development)

let API_BASE_URL;

if (process.env.REACT_APP_API_URL) {
  // Build-time environment variable
  API_BASE_URL = process.env.REACT_APP_API_URL;
} else if (window.REACT_APP_API_URL && window.REACT_APP_API_URL !== '') {
  // Runtime configuration (set via script tag in index.html)
  API_BASE_URL = window.REACT_APP_API_URL;
} else if (process.env.NODE_ENV === 'production') {
  // In production with nginx proxy, use empty string for relative URLs
  // Nginx will proxy /api requests to backend
  API_BASE_URL = '';
} else {
  // Development fallback
  API_BASE_URL = 'http://localhost:5001';
}

// Remove trailing slash
if (API_BASE_URL) {
  API_BASE_URL = API_BASE_URL.replace(/\/$/, '');
}

export const API_URL = API_BASE_URL;
export default API_URL;

