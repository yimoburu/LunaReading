# Nginx Configuration for LunaReading

## Overview

The nginx configuration proxies all API requests to the backend Cloud Run service while serving the React frontend as static files.

## Configuration Files

### `nginx.conf`
- **Purpose**: Development/local testing configuration
- **Backend URL**: Hardcoded to `https://lunareading-backend-bkumsoprkq-uc.a.run.app`
- **Usage**: For local development or when backend URL is fixed

### `nginx.conf.template`
- **Purpose**: Production deployment configuration
- **Backend URL**: Uses `${BACKEND_URL}` environment variable (substituted at container startup)
- **Backend Host**: Uses `${BACKEND_HOST}` for Host header (extracted from BACKEND_URL)
- **Usage**: Used in Docker container, processed by `docker-entrypoint.sh`

## API Routes

All backend API routes are under `/api` prefix and are proxied to the backend:

### Authentication Routes
- `POST /api/register` - User registration
- `POST /api/login` - User login

### Profile Routes
- `GET /api/profile` - Get user profile (requires auth)
- `PUT /api/profile` - Update user profile (requires auth)

### Session Routes
- `POST /api/sessions` - Create new reading session (requires auth)
- `GET /api/sessions` - Get all user sessions (requires auth)
- `GET /api/sessions/<id>` - Get specific session (requires auth)

### Question Routes
- `POST /api/questions/<id>/answer` - Submit answer (requires auth)
- `GET /api/questions/<id>/answers` - Get all answers for question (requires auth)

### Admin Routes
- `GET /api/admin/users` - Get all users with statistics (requires auth)

### Diagnostic Routes
- `GET /api/db-status` - Database connection status (no auth required)
- `GET /` - Health check endpoint (no auth required)

## Configuration Details

### Proxy Settings

```nginx
location /api {
    proxy_pass ${BACKEND_URL}/api;
    proxy_set_header Host ${BACKEND_HOST};
    # ... other headers
}
```

**Important Notes:**
1. **No trailing slash** in `proxy_pass` - ensures full path is preserved:
   - `/api/register` → `https://backend.com/api/register`
   - `/api/sessions/123` → `https://backend.com/api/sessions/123`

2. **Host header** must be the backend's hostname (not frontend):
   - Cloud Run uses Host header for routing
   - Extracted from BACKEND_URL in `docker-entrypoint.sh`

3. **Path preservation**:
   - All `/api/*` requests are forwarded to backend
   - Query parameters and request body are preserved

### Timeout Settings

```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
send_timeout 300s;
```

- **proxy_connect_timeout**: Time to establish connection to backend
- **proxy_send_timeout**: Time to send request to backend
- **proxy_read_timeout**: Time to read response from backend
- **send_timeout**: Time to send response to client

These are set high to accommodate database operations that may take time.

### CORS Headers

```nginx
add_header Access-Control-Allow-Origin * always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
```

CORS headers are added to all API responses. The backend also handles CORS, so these provide additional coverage.

### Static File Serving

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

- Serves React app static files
- Falls back to `index.html` for client-side routing (SPA behavior)

### Static Asset Caching

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

Static assets are cached for 1 year with immutable cache control.

## Environment Variables

### Required for Production

- `BACKEND_URL`: Full backend URL (e.g., `https://lunareading-backend-xxx-uc.a.run.app`)
  - Used in `nginx.conf.template` for `proxy_pass`
  - Should NOT include `/api` suffix
  - Extracted automatically in `docker-entrypoint.sh`

- `BACKEND_HOST`: Backend hostname (e.g., `lunareading-backend-xxx-uc.a.run.app`)
  - Extracted from `BACKEND_URL` in `docker-entrypoint.sh`
  - Used for `Host` header in proxy requests

## Deployment

### Local Development

1. Use `nginx.conf` directly:
   ```bash
   nginx -c /path/to/nginx.conf
   ```

2. Or use Docker with environment variable:
   ```bash
   docker run -e BACKEND_URL=https://backend-url -v $(pwd)/nginx.conf.template:/etc/nginx/templates/default.conf.template ...
   ```

### Production (Cloud Run)

1. `docker-entrypoint.sh` processes `nginx.conf.template`:
   - Extracts `BACKEND_HOST` from `BACKEND_URL`
   - Substitutes variables using `envsubst`
   - Validates nginx configuration

2. Frontend service must have `BACKEND_URL` environment variable set:
   ```bash
   gcloud run services update lunareading-frontend \
     --set-env-vars "BACKEND_URL=https://lunareading-backend-xxx-uc.a.run.app"
   ```

## Troubleshooting

### 404 Errors on API Routes

1. **Check backend URL**:
   ```bash
   echo $BACKEND_URL
   curl $BACKEND_URL/api/db-status
   ```

2. **Verify nginx config**:
   ```bash
   # In container
   cat /etc/nginx/conf.d/default.conf | grep proxy_pass
   ```

3. **Check Host header**:
   - Must match backend hostname exactly
   - Cloud Run is sensitive to Host header

### 502 Bad Gateway

1. **Backend not accessible**:
   - Verify backend service is running
   - Check Cloud Run service status

2. **Timeout issues**:
   - Increase timeout values in nginx config
   - Check backend logs for slow queries

### CORS Errors

1. **Check CORS headers**:
   ```bash
   curl -I https://frontend-url/api/register
   ```

2. **Verify backend CORS**:
   - Backend should also handle CORS
   - Check `backend/__init__.py` for CORS configuration

## Testing

### Test API Proxy

```bash
# Test from frontend URL
curl https://frontend-url/api/db-status

# Should return same as:
curl https://backend-url/api/db-status
```

### Test Static Files

```bash
# Should serve React app
curl https://frontend-url/

# Should return index.html
curl https://frontend-url/index.html
```

### Verify Configuration

```bash
# Check nginx config in container
docker exec <container> cat /etc/nginx/conf.d/default.conf

# Test nginx config syntax
docker exec <container> nginx -t
```

