# Troubleshooting Cloud Run Deployment

## Common Issues and Solutions

### Issue: Container Failed to Start

**Error**: "The user-provided container failed to start and listen on the port defined provided by the PORT=8080 environment variable"

**Solutions**:

1. **Check that the app listens on 0.0.0.0, not 127.0.0.1**
   - Cloud Run requires binding to 0.0.0.0
   - The code has been updated to automatically use 0.0.0.0 when PORT is set

2. **Check application logs**:
   ```bash
   gcloud run services logs read lunareading-backend --limit 50
   ```

3. **Test locally with PORT set**:
   ```bash
   PORT=8080 python backend/app.py
   ```

### Issue: Database Path Issues

**Problem**: SQLite database might not persist or have permission issues

**Solutions**:

1. **Use Cloud SQL** (recommended for production):
   ```bash
   # Create Cloud SQL instance
   gcloud sql instances create lunareading-db \
     --database-version=POSTGRES_14 \
     --tier=db-f1-micro \
     --region=us-central1
   ```

2. **Or use a persistent volume** (for SQLite):
   - Mount Cloud Storage bucket
   - Or use Cloud Filestore

3. **For testing**: The current setup uses SQLite in the container (data is lost on restart)

### Issue: Environment Variables Not Set

**Solution**: Set them after deployment:
```bash
gcloud run services update lunareading-backend \
  --update-env-vars "OPENAI_API_KEY=your-key,JWT_SECRET_KEY=your-secret"
```

### Issue: Timeout During Startup

**Solution**: Increase startup timeout:
```bash
gcloud run services update lunareading-backend \
  --timeout=300 \
  --cpu-throttling
```

### Viewing Logs

```bash
# View recent logs
gcloud run services logs read lunareading-backend --limit 100

# Follow logs in real-time
gcloud run services logs tail lunareading-backend

# View in Cloud Console
# https://console.cloud.google.com/run
```

### Testing the Container Locally

```bash
# Build the image
docker build -t lunareading-backend -f Dockerfile.backend .

# Run with PORT environment variable
docker run -p 8080:8080 -e PORT=8080 -e OPENAI_API_KEY=your-key lunareading-backend

# Test
curl http://localhost:8080/
```

### Redeploy After Fixes

After fixing issues, rebuild and redeploy:

```bash
./deploy-no-docker.sh lunareading-app us-central1
```

Or just rebuild the backend:

```bash
# Create temporary cloudbuild config
cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/lunareading-app/lunareading-backend:latest', '-f', 'Dockerfile.backend', '.']
images:
- 'gcr.io/lunareading-app/lunareading-backend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-backend.yaml .

# Redeploy
gcloud run deploy lunareading-backend \
  --image gcr.io/lunareading-app/lunareading-backend:latest \
  --region us-central1
```

