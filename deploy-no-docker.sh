#!/bin/bash
# Deploy to Google Cloud Run without requiring local Docker
# Uses Cloud Build to build images in the cloud

set -e

PROJECT_ID=${1:-"lunareading-app"}
REGION=${2:-"us-central1"}

echo "🚀 Deploying LunaReading to Google Cloud Run (No Local Docker Required)"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Parse .env file for environment variables and Cloud SQL instance
CLOUDSQL_INSTANCE=""
ENV_VARS=""
ENV_COUNT=0

if [ -f .env ]; then
    echo "📋 Reading environment variables from .env file..."
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Skip lines that don't have = sign
        if [[ ! "$line" =~ = ]]; then
            continue
        fi
        
        # Extract key and value
        KEY=$(echo "$line" | cut -d'=' -f1 | xargs)
        VALUE=$(echo "$line" | cut -d'=' -f2- | xargs)
        
        # Skip if key or value is empty
        if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
            continue
        fi
        
        # Extract Cloud SQL instance connection name
        if [ "$KEY" == "CLOUDSQL_INSTANCE_CONNECTION_NAME" ]; then
            CLOUDSQL_INSTANCE="$VALUE"
            # Remove quotes if present
            CLOUDSQL_INSTANCE=$(echo "$CLOUDSQL_INSTANCE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        fi
        
        # Handle password strings: remove nested quotes but keep one set
        is_password=$(echo "$KEY" | grep -qiE "(PASSWORD|SECRET|API_KEY|KEY)" && echo "yes" || echo "no")
        if [ "$is_password" == "yes" ]; then
            # Check if original has quotes (single or double)
            original_has_quotes=false
            first_char="${VALUE:0:1}"
            last_char="${VALUE: -1}"
            if [ "$first_char" == '"' ] && [ "$last_char" == '"' ]; then
                original_has_quotes=true
            elif [ "$first_char" == "'" ] && [ "$last_char" == "'" ]; then
                original_has_quotes=true
            fi
            
            # Strip all nested quotes until we get to unquoted content
            while true; do
                first_char="${VALUE:0:1}"
                last_char="${VALUE: -1}"
                if [ "$first_char" == '"' ] && [ "$last_char" == '"' ]; then
                    VALUE="${VALUE:1:-1}"
                elif [ "$first_char" == "'" ] && [ "$last_char" == "'" ]; then
                    VALUE="${VALUE:1:-1}"
                else
                    break
                fi
            done
            
            # If original had quotes, add back one set of double quotes
            if [ "$original_has_quotes" == "true" ]; then
                VALUE="\"$VALUE\""
            fi
        else
            # For non-passwords: remove all quotes
            VALUE=$(echo "$VALUE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        fi
        
        # Skip sensitive values in output (mask password)
        if [[ "$KEY" == *"PASSWORD"* ]] || [[ "$KEY" == *"SECRET"* ]] || [[ "$KEY" == *"API_KEY"* ]]; then
            DISPLAY_VALUE="***"
        else
            DISPLAY_VALUE="$VALUE"
        fi
        
        echo "   ✅ $KEY=$DISPLAY_VALUE"
        
        # Build env vars string for gcloud
        if [ -z "$ENV_VARS" ]; then
            ENV_VARS="${KEY}=${VALUE}"
        else
            ENV_VARS="${ENV_VARS},${KEY}=${VALUE}"
        fi
        
        ENV_COUNT=$((ENV_COUNT + 1))
    done < .env
    
    if [ $ENV_COUNT -gt 0 ]; then
        echo "   Found $ENV_COUNT environment variable(s)"
    else
        echo "   ⚠️  No environment variables found in .env file"
        ENV_VARS=""
    fi
    
    if [ -n "$CLOUDSQL_INSTANCE" ]; then
        echo "   🔗 Cloud SQL instance: $CLOUDSQL_INSTANCE"
    else
        echo "   ⚠️  CLOUDSQL_INSTANCE_CONNECTION_NAME not found in .env"
        echo "      Cloud SQL connection may fail. Add it to .env file."
    fi
    echo ""
else
    echo "⚠️  Warning: .env file not found"
    echo "   Environment variables will need to be set manually after deployment"
    echo ""
fi

# Set project
echo "📋 Setting Google Cloud project..."
gcloud config set project $PROJECT_ID

# Enable APIs
echo "🔧 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com --quiet || true
gcloud services enable run.googleapis.com --quiet || true
gcloud services enable artifactregistry.googleapis.com --quiet || true

# Build and deploy backend
echo ""
echo "🏗️  Building backend using Cloud Build..."

# Create temporary cloudbuild config for backend
cat > /tmp/cloudbuild-backend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/lunareading-backend:latest', '-f', 'Dockerfile.backend', '.']
images:
- 'gcr.io/$PROJECT_ID/lunareading-backend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-backend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-backend.yaml

echo "🚀 Deploying backend to Cloud Run..."

# Build base deploy command
DEPLOY_CMD="gcloud run deploy lunareading-backend \
  --image gcr.io/$PROJECT_ID/lunareading-backend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10"

# Add Cloud SQL instance if found
if [ -n "$CLOUDSQL_INSTANCE" ]; then
    echo "   🔗 Adding Cloud SQL instance: $CLOUDSQL_INSTANCE"
    DEPLOY_CMD="$DEPLOY_CMD --add-cloudsql-instances $CLOUDSQL_INSTANCE"
    
    # Note about service account permissions
    echo "   🔐 Note: Service account needs Cloud SQL Client role"
    echo "   💡 After deployment, grant permission if connection fails:"
    echo "      # Get the service account:"
    echo "      SERVICE_ACCOUNT=\$(gcloud run services describe lunareading-backend \\"
    echo "        --region $REGION --format 'value(spec.template.spec.serviceAccountName)')"
    echo "      # Grant role:"
    echo "      gcloud projects add-iam-policy-binding $PROJECT_ID \\"
    echo "        --member=\"serviceAccount:\$SERVICE_ACCOUNT\" \\"
    echo "        --role=\"roles/cloudsql.client\""
else
    echo "   ⚠️  No Cloud SQL instance found - connection may fail"
    echo "      Set CLOUDSQL_INSTANCE_CONNECTION_NAME in .env or update service manually"
fi

# Add environment variables if available
if [ -n "$ENV_VARS" ]; then
    echo "   📝 Setting environment variables from .env file..."
    # Show what will be set (mask sensitive values)
    echo "   Environment variables to set:"
    IFS=',' read -ra VAR_PAIRS <<< "$ENV_VARS"
    SECRET_VARS_TO_CLEAR=""
    for pair in "${VAR_PAIRS[@]}"; do
        KEY=$(echo "$pair" | cut -d'=' -f1)
        if [[ "$KEY" == *"PASSWORD"* ]] || [[ "$KEY" == *"SECRET"* ]] || [[ "$KEY" == *"API_KEY"* ]]; then
            echo "     - $KEY=***"
            # Collect secret variable names that might need to be cleared
            if [ -z "$SECRET_VARS_TO_CLEAR" ]; then
                SECRET_VARS_TO_CLEAR="$KEY"
            else
                SECRET_VARS_TO_CLEAR="$SECRET_VARS_TO_CLEAR,$KEY"
            fi
        else
            VALUE=$(echo "$pair" | cut -d'=' -f2-)
            # Truncate long values for display
            if [ ${#VALUE} -gt 50 ]; then
                VALUE="${VALUE:0:47}..."
            fi
            echo "     - $KEY=$VALUE"
        fi
    done
    
    # Note: We'll clear secrets separately if deployment fails due to secret conflicts
    DEPLOY_CMD="$DEPLOY_CMD --set-env-vars \"$ENV_VARS\""
else
    echo "   ⚠️  No environment variables from .env file"
    echo "   Set them manually after deployment using:"
    echo "   ./scripts/update_cloud_run_env.py lunareading-backend $REGION"
fi

# Execute deploy command
DEPLOY_FAILED=0
echo "DEPLOY_CMD: $DEPLOY_CMD"
if ! eval "$DEPLOY_CMD"; then
    # If deployment failed due to secret conflicts, try clearing secrets first
    if [ -n "$ENV_VARS" ] && [ -n "$SECRET_VARS_TO_CLEAR" ]; then
        echo ""
        echo "⚠️  Deployment failed. Attempting to clear secret references first..."
        
        # Try to remove secrets that conflict with env vars
        # Build remove-secrets command (comma-separated list)
        REMOVE_SECRETS_LIST=""
        for secret_var in $(echo "$SECRET_VARS_TO_CLEAR" | tr ',' ' '); do
            if [ -z "$REMOVE_SECRETS_LIST" ]; then
                REMOVE_SECRETS_LIST="$secret_var"
            else
                REMOVE_SECRETS_LIST="$REMOVE_SECRETS_LIST,$secret_var"
            fi
        done
        
        echo "   🔓 Removing secret references: $REMOVE_SECRETS_LIST"
        REMOVE_SECRET_CMD="gcloud run services update lunareading-backend \
          --region $REGION \
          --project $PROJECT_ID \
          --remove-secrets \"$REMOVE_SECRETS_LIST\" \
          --quiet 2>&1"
        
        # Try to remove secrets (ignore errors if they don't exist)
        eval "$REMOVE_SECRET_CMD" || echo "   ℹ️  Note: Some secrets may not exist (this is OK)"
        
        # Retry deployment
        echo "   🔄 Retrying deployment..."
        if eval "$DEPLOY_CMD"; then
            DEPLOY_FAILED=0
            echo "   ✅ Deployment succeeded after clearing secrets"
        else
            DEPLOY_FAILED=1
        fi
    else
        DEPLOY_FAILED=1
    fi
fi

# Explicitly update environment variables after deployment to ensure they're set correctly
# This is important if the service already exists and env vars need to be updated
if [ -n "$ENV_VARS" ]; then
    echo ""
    echo "🔄 Verifying and updating environment variables..."
    
    # Get current CLOUDSQL_INSTANCE_CONNECTION_NAME from Cloud Run
    CURRENT_INSTANCE=$(gcloud run services describe lunareading-backend \
      --region $REGION \
      --project $PROJECT_ID \
      --format='value(spec.template.spec.containers[0].env)' 2>/dev/null | \
      python3 -c "import sys, re; data=sys.stdin.read(); match=re.search(r\"\{'name':\s*'CLOUDSQL_INSTANCE_CONNECTION_NAME',\s*'value':\s*'([^']+)'\", data); print(match.group(1) if match else '')" || echo "")
    
    if [ -n "$CURRENT_INSTANCE" ] && [ "$CURRENT_INSTANCE" != "$CLOUDSQL_INSTANCE" ]; then
        echo "   ⚠️  Detected old instance name: $CURRENT_INSTANCE"
        echo "   📝 Updating to new instance name: $CLOUDSQL_INSTANCE"
    fi
    
    # Check for secret variables that need to be cleared first
    SECRET_VARS_TO_CLEAR=""
    IFS=',' read -ra VAR_PAIRS <<< "$ENV_VARS"
    for pair in "${VAR_PAIRS[@]}"; do
        KEY=$(echo "$pair" | cut -d'=' -f1)
        if [[ "$KEY" == *"PASSWORD"* ]] || [[ "$KEY" == *"SECRET"* ]] || [[ "$KEY" == *"API_KEY"* ]]; then
            if [ -z "$SECRET_VARS_TO_CLEAR" ]; then
                SECRET_VARS_TO_CLEAR="$KEY"
            else
                SECRET_VARS_TO_CLEAR="$SECRET_VARS_TO_CLEAR,$KEY"
            fi
        fi
    done
    
    # Clear secret references first if needed
    if [ -n "$SECRET_VARS_TO_CLEAR" ]; then
        echo "   🔓 Removing secret references before updating environment variables..."
        # Build remove-secrets command (comma-separated list)
        REMOVE_SECRETS_LIST=""
        for secret_var in $(echo "$SECRET_VARS_TO_CLEAR" | tr ',' ' '); do
            if [ -z "$REMOVE_SECRETS_LIST" ]; then
                REMOVE_SECRETS_LIST="$secret_var"
            else
                REMOVE_SECRETS_LIST="$REMOVE_SECRETS_LIST,$secret_var"
            fi
        done
        
        REMOVE_SECRET_CMD="gcloud run services update lunareading-backend \
          --region $REGION \
          --project $PROJECT_ID \
          --remove-secrets \"$REMOVE_SECRETS_LIST\" \
          --quiet 2>&1"
        
        # Try to remove secrets (ignore errors if they don't exist)
        if eval "$REMOVE_SECRET_CMD" 2>/dev/null; then
            echo "     ✅ Removed secret references"
        else
            echo "     ℹ️  Note: Some secrets may not exist (this is OK, continuing...)"
        fi
    fi
    
    # Update environment variables explicitly
    UPDATE_ENV_CMD="gcloud run services update lunareading-backend \
      --region $REGION \
      --project $PROJECT_ID \
      --update-env-vars \"$ENV_VARS\" \
      --quiet"
    
    if eval "$UPDATE_ENV_CMD"; then
        echo "   ✅ Environment variables updated successfully"
        
        # Verify the update
        UPDATED_INSTANCE=$(gcloud run services describe lunareading-backend \
          --region $REGION \
          --project $PROJECT_ID \
          --format='value(spec.template.spec.containers[0].env)' 2>/dev/null | \
          python3 -c "import sys, re; data=sys.stdin.read(); match=re.search(r\"\{'name':\s*'CLOUDSQL_INSTANCE_CONNECTION_NAME',\s*'value':\s*'([^']+)'\", data); print(match.group(1) if match else '')" || echo "")
        
        if [ -n "$UPDATED_INSTANCE" ] && [ "$UPDATED_INSTANCE" == "$CLOUDSQL_INSTANCE" ]; then
            echo "   ✅ Verified: CLOUDSQL_INSTANCE_CONNECTION_NAME is now set to: $UPDATED_INSTANCE"
        else
            echo "   ⚠️  Warning: Could not verify environment variable update"
        fi
    else
        echo "   ⚠️  Warning: Failed to update environment variables"
        echo "   You may need to update them manually:"
        echo "   ./scripts/update_cloud_run_env.py lunareading-backend $REGION $PROJECT_ID"
    fi
fi

if [ $DEPLOY_FAILED -eq 1 ]; then
    echo ""
    echo "⚠️  Backend deployment had issues."
    if [ -z "$CLOUDSQL_INSTANCE" ]; then
        echo "   Missing CLOUDSQL_INSTANCE_CONNECTION_NAME in .env file"
    fi
    if [ -z "$ENV_VARS" ]; then
        echo "   You may need to set environment variables:"
        echo "   Run: ./scripts/update_cloud_run_env.py lunareading-backend $REGION"
    fi
fi

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend \
  --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Failed to get backend URL"
    exit 1
fi

echo "✅ Backend URL: $BACKEND_URL"

# Build and deploy frontend
echo ""
echo "🏗️  Building frontend using Cloud Build..."

# Create temporary cloudbuild config for frontend
cat > /tmp/cloudbuild-frontend.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/lunareading-frontend:latest', '-f', 'Dockerfile.frontend', '.']
images:
- 'gcr.io/$PROJECT_ID/lunareading-frontend:latest'
EOF

gcloud builds submit --config=/tmp/cloudbuild-frontend.yaml . --region=$REGION --quiet
rm /tmp/cloudbuild-frontend.yaml

echo "🚀 Deploying frontend to Cloud Run..."
gcloud run deploy lunareading-frontend \
  --image gcr.io/$PROJECT_ID/lunareading-frontend:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --port 80 \
  --memory 256Mi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars "BACKEND_URL=$BACKEND_URL"

# Get service URLs
echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Service URLs:"
echo "Backend:  $BACKEND_URL"
FRONTEND_URL=$(gcloud run services describe lunareading-frontend \
  --region $REGION --format 'value(status.url)')
echo "Frontend: $FRONTEND_URL"
echo ""
echo "📝 Next steps:"

if [ -z "$ENV_VARS" ]; then
    echo "1. Set environment variables for backend:"
    echo "   ./scripts/update_cloud_run_env.py lunareading-backend $REGION"
    echo "   Or manually update via Cloud Console"
    echo ""
else
    echo "1. ✅ Environment variables from .env have been set"
    echo "   To update them later, run:"
    echo "   ./scripts/update_cloud_run_env.py lunareading-backend $REGION"
    echo ""
fi

if [ -z "$CLOUDSQL_INSTANCE" ]; then
    echo "2. ⚠️  IMPORTANT: Add Cloud SQL instance to service:"
    echo "   gcloud run services update lunareading-backend \\"
    echo "     --region $REGION \\"
    echo "     --add-cloudsql-instances PROJECT:REGION:INSTANCE"
    echo ""
    echo "3. Verify backend is working:"
else
    echo "2. ✅ Cloud SQL instance has been added to the service"
    echo ""
    echo "3. Verify backend is working:"
fi
echo "   curl $BACKEND_URL/"
echo ""
echo "4. Test your deployment!"
echo ""
echo "💡 Tip: Check logs if there are issues:"
echo "   gcloud run services logs read lunareading-backend --region $REGION --limit 50"

