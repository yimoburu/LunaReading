# How to Check Cloud Run Logs

The deployment is failing because the container isn't starting. Here's how to check the logs:

## View Logs via Command Line

```bash
# View recent logs
gcloud run services logs read lunareading-backend --region us-central1 --limit 50

# Follow logs in real-time
gcloud run services logs tail lunareading-backend --region us-central1

# View logs with more details
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=lunareading-backend" --limit 50 --format json
```

## View Logs via Web Console

1. Go to: https://console.cloud.google.com/run
2. Click on `lunareading-backend` service
3. Click on the revision (e.g., `lunareading-backend-00002-cxh`)
4. Click "Logs" tab

Or use the direct URL from the error message:
```
https://console.cloud.google.com/logs/viewer?project=lunareading-app&resource=cloud_run_revision/service_name/lunareading-backend
```

## Common Issues to Look For

1. **Import errors**: Check if all Python packages are installed
2. **Database errors**: SQLite might have permission issues
3. **Environment variable errors**: Missing OPENAI_API_KEY or other vars
4. **Port binding errors**: App not listening on 0.0.0.0:8080
5. **Startup timeout**: App taking too long to start

## After Checking Logs

Once you identify the issue from the logs, you can:
1. Fix the code
2. Rebuild the image
3. Redeploy

The latest changes use gunicorn which is more reliable for Cloud Run.

