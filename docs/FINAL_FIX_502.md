# Final Fix for 502 Bad Gateway

## Root Cause
The 502 error occurs because nginx can't proxy to the backend. This happens when:
1. `BACKEND_URL` environment variable is not set in the frontend service
2. Nginx template is not processed correctly
3. The substituted URL is incorrect

## Solution

### Step 1: Set BACKEND_URL Environment Variable

```bash
# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')

# Set it in frontend service
gcloud run services update lunareading-frontend \
  --region us-central1 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"
```

### Step 2: Rebuild and Redeploy Frontend

```bash
./fix_backend_url.sh us-central1
```

This script will:
- Set BACKEND_URL environment variable
- Rebuild frontend with updated Dockerfile
- Deploy with correct configuration
- Test the proxy

## How It Works

1. **Startup Script**: When container starts, `/docker-entrypoint.d/10-process-template.sh` runs
2. **Template Processing**: Script uses `envsubst` to substitute `${BACKEND_URL}` in the template
3. **Config Generation**: Final nginx config is written to `/etc/nginx/conf.d/default.conf`
4. **Verification**: Script verifies substitution worked (exits with error if not)
5. **Nginx Starts**: nginx:alpine entrypoint starts nginx with the processed config

## Verify It's Working

After deployment, check logs:
```bash
gcloud run services logs read lunareading-frontend --region us-central1 --limit 30 | grep -E "(BACKEND_URL|proxy_pass|Processing)"
```

You should see:
- "Processing nginx template with BACKEND_URL=..."
- "✅ BACKEND_URL substituted successfully"
- "proxy_pass will use: proxy_pass https://..."

## Test

```bash
./test_proxy_comparison.sh us-central1
```

Both direct and proxy calls should return 200/201.

## If Still Failing

1. **Check BACKEND_URL is set**:
   ```bash
   gcloud run services describe lunareading-frontend --region us-central1 --format='value(spec.template.spec.containers[0].env)' | grep BACKEND_URL
   ```

2. **Check startup logs**:
   ```bash
   gcloud run services logs read lunareading-frontend --region us-central1 --limit 50 | grep -E "(Processing|BACKEND_URL|ERROR)"
   ```

3. **Check nginx error logs**:
   ```bash
   ./check_nginx_errors.sh us-central1
   ```

4. **Verify template was processed**:
   The logs should show "✅ BACKEND_URL substituted successfully"

