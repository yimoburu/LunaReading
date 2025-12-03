# Diagnosing 502 Bad Gateway

## Quick Diagnosis

Run these commands to diagnose the issue:

```bash
# 1. Check if BACKEND_URL is set
gcloud run services describe lunareading-frontend --region us-central1 \
  --format='value(spec.template.spec.containers[0].env)' | grep BACKEND_URL

# 2. Check startup logs for template processing
./check_startup_logs.sh us-central1

# 3. Check nginx error logs
./check_nginx_errors.sh us-central1

# 4. Test proxy directly
./test_proxy_comparison.sh us-central1
```

## What to Look For

### In Startup Logs
- ✅ "Processing nginx template with BACKEND_URL=..."
- ✅ "✅ BACKEND_URL substituted successfully"
- ✅ "proxy_pass: proxy_pass https://..."
- ❌ "ERROR: BACKEND_URL was not substituted!"
- ❌ "WARNING: BACKEND_URL not set"

### In Error Logs
- `upstream sent too big header` → Increase buffer sizes (already fixed)
- `upstream timed out` → Increase timeouts (already fixed)
- `no resolver defined` → Need resolver for variables (removed, using substitution)
- `502 Bad Gateway` → Can't connect to backend (BACKEND_URL issue)

## Common Issues

### Issue 1: BACKEND_URL Not Set
**Symptom**: Startup logs show "WARNING: BACKEND_URL not set"
**Fix**: 
```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')
gcloud run services update lunareading-frontend --region us-central1 --set-env-vars "BACKEND_URL=$BACKEND_URL"
```

### Issue 2: Template Not Processed
**Symptom**: Startup logs show "ERROR: BACKEND_URL was not substituted!"
**Fix**: Rebuild frontend - the startup script should handle this
```bash
./fix_backend_url.sh us-central1
```

### Issue 3: Wrong Backend URL
**Symptom**: Template processed but proxy still fails
**Fix**: Verify BACKEND_URL matches actual backend URL
```bash
BACKEND_URL=$(gcloud run services describe lunareading-backend --region us-central1 --format 'value(status.url)')
echo "Should be: $BACKEND_URL"
gcloud run services describe lunareading-frontend --region us-central1 --format='value(spec.template.spec.containers[0].env)' | grep BACKEND_URL
```

## Step-by-Step Fix

1. **Set BACKEND_URL**:
   ```bash
   ./fix_backend_url.sh us-central1
   ```

2. **Check startup logs**:
   ```bash
   ./check_startup_logs.sh us-central1
   ```
   Should see "✅ BACKEND_URL substituted successfully"

3. **Test proxy**:
   ```bash
   ./test_proxy_comparison.sh us-central1
   ```
   Both should return 200/201

4. **If still failing**, check error logs:
   ```bash
   ./check_nginx_errors.sh us-central1
   ```

