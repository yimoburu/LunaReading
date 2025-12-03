# Debugging Frontend-Backend Connection Issues

## Quick Debug Scripts

### Comprehensive Debug
```bash
./debug_frontend_backend.sh us-central1
```
This will check:
- Environment variables
- Direct backend calls
- Frontend proxy calls
- Nginx logs
- Backend logs
- Verbose curl output

### Compare Direct vs Proxy
```bash
./test_proxy_comparison.sh us-central1
```
This directly compares a backend call vs a proxy call to see the difference.

## Manual Debugging Steps

### 1. Check Environment Variables

```bash
# Check if BACKEND_URL is set in frontend
gcloud run services describe lunareading-frontend \
  --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)'
```

If not set:
```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')
gcloud run services update lunareading-frontend \
  --region us-central1 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"
```

### 2. Test Direct Backend

```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')

# Test registration
curl -X POST $BACKEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123","grade_level":3}'
```

### 3. Test Through Frontend Proxy

```bash
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region us-central1 --format 'value(status.url)')

# Test registration through proxy
curl -X POST $FRONTEND_URL/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"test123","grade_level":3}'
```

### 4. Compare Responses

If direct works but proxy doesn't:
- **502 Bad Gateway**: Nginx can't reach backend
  - Check BACKEND_URL is set correctly
  - Rebuild frontend: `./fix_frontend_502.sh us-central1`
  
- **504 Gateway Timeout**: Nginx timeout too short
  - Increase timeouts: `./fix_504_timeout.sh us-central1`

- **Other errors**: Check nginx logs

### 5. Check Browser Console

1. Open browser DevTools (F12)
2. Go to Console tab
3. Look for JavaScript errors
4. Go to Network tab
5. Try to register/login
6. Check the request:
   - URL (should be `/api/register` or `/api/login`)
   - Method (should be POST)
   - Headers (should include Content-Type: application/json)
   - Request payload
   - Response status and body

### 6. Check Frontend Code

Verify the frontend is using relative URLs:

```javascript
// Should be empty string or relative path in production
const API_URL = '';  // or '/api' if not using nginx proxy
```

Check `frontend/src/config.js`:
- In production, should use empty string for relative URLs
- Nginx will proxy `/api/*` to backend

### 7. Check Nginx Configuration

```bash
# View nginx logs
gcloud run services logs read lunareading-frontend --region us-central1 --limit 50 | grep -E "(error|proxy|upstream)"
```

Common nginx errors:
- `upstream sent too big header`: Increase buffer sizes (already fixed)
- `upstream timed out`: Increase timeouts (already fixed)
- `no resolver defined`: Backend URL resolution issue
- `502 Bad Gateway`: Can't connect to backend

### 8. Verify Nginx Template Processing

The nginx config should have the actual backend URL, not `${BACKEND_URL}`:

```bash
# Check if nginx processed the template correctly
# This is harder to check, but you can see in logs if proxy_pass is working
```

## Common Issues and Fixes

### Issue: 502 Bad Gateway
**Cause**: Nginx can't reach backend
**Fix**: 
1. Set BACKEND_URL environment variable
2. Rebuild frontend: `./fix_frontend_502.sh us-central1`

### Issue: 504 Gateway Timeout
**Cause**: Backend taking too long (OpenAI calls)
**Fix**: 
1. Increase nginx timeouts: `./fix_504_timeout.sh us-central1`
2. Increase backend timeout: `gcloud run services update lunareading-backend --region us-central1 --timeout 300`

### Issue: CORS errors in browser
**Cause**: Backend not allowing frontend origin
**Fix**: Check backend CORS configuration (should allow all origins)

### Issue: Request goes to wrong URL
**Cause**: Frontend using wrong API URL
**Fix**: Check `frontend/src/config.js` - should use relative URLs in production

### Issue: Works in curl but not browser
**Cause**: Browser-specific issues (CORS, cookies, etc.)
**Fix**: 
1. Check browser console for errors
2. Check Network tab for actual request
3. Verify CORS headers in response

## Testing Checklist

- [ ] Direct backend call works
- [ ] Proxy call works (via curl)
- [ ] BACKEND_URL is set in frontend service
- [ ] Frontend uses relative URLs (`/api/...`)
- [ ] Nginx timeouts are sufficient (300s)
- [ ] Backend timeout is sufficient (300s)
- [ ] No CORS errors in browser console
- [ ] Network tab shows correct request URL
- [ ] Response status is 200/201 (not 502/504)

