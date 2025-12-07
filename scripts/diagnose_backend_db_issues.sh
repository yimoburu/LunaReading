#!/bin/bash
# Diagnose why backend server database queries don't work
# when direct database queries work

set -e

REGION=${1:-"us-central1"}
SERVICE_NAME="lunareading-backend"
PROJECT_ID=${2:-"lunareading-app"}

echo "🔍 Diagnosing Backend Server Database Connection Issues"
echo "======================================================"
echo ""
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo "Project: $PROJECT_ID"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_check() {
    echo -e "${YELLOW}Checking:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Check if Cloud SQL instance is attached to Cloud Run service
print_check "1. Cloud SQL instance attachment to Cloud Run service"
CLOUDSQL_ANNOTATION=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(spec.template.metadata.annotations."run.googleapis.com/cloudsql-instances")' 2>/dev/null || echo "")

if [ -z "$CLOUDSQL_ANNOTATION" ]; then
    print_error "Cloud SQL instance NOT attached to Cloud Run service"
    echo "   This is REQUIRED for Cloud Run to connect to Cloud SQL"
    echo "   Fix with:"
    echo "   gcloud run services update $SERVICE_NAME \\"
    echo "     --region $REGION \\"
    echo "     --add-cloudsql-instances <instance-connection-name>"
else
    print_success "Cloud SQL instance attached: $CLOUDSQL_ANNOTATION"
fi
echo ""

# 2. Check service account permissions
print_check "2. Service account Cloud SQL permissions"
SERVICE_ACCOUNT=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(spec.template.spec.serviceAccountName)' 2>/dev/null || echo "")

if [ -z "$SERVICE_ACCOUNT" ]; then
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format 'value(projectNumber)' 2>/dev/null || echo "")
    if [ -n "$PROJECT_NUMBER" ]; then
        SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
        print_warning "Using default Compute Engine service account: $SERVICE_ACCOUNT"
    else
        print_error "Could not determine service account"
        SERVICE_ACCOUNT="UNKNOWN"
    fi
else
    print_success "Service account: $SERVICE_ACCOUNT"
fi

if [ "$SERVICE_ACCOUNT" != "UNKNOWN" ]; then
    # Check if service account has Cloud SQL Client role
    HAS_ROLE=$(gcloud projects get-iam-policy $PROJECT_ID \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT} AND bindings.role:roles/cloudsql.client" \
      --format="value(bindings.role)" 2>/dev/null || echo "")
    
    if [ -z "$HAS_ROLE" ]; then
        print_error "Service account does NOT have roles/cloudsql.client permission"
        echo "   Grant permission with:"
        echo "   gcloud projects add-iam-policy-binding $PROJECT_ID \\"
        echo "     --member=\"serviceAccount:${SERVICE_ACCOUNT}\" \\"
        echo "     --role=\"roles/cloudsql.client\""
    else
        print_success "Service account has roles/cloudsql.client permission"
    fi
fi
echo ""

# 3. Check environment variables
print_check "3. Environment variables configuration"
ENV_DATA=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)

REQUIRED_VARS=("CLOUDSQL_INSTANCE_CONNECTION_NAME" "CLOUDSQL_DATABASE" "CLOUDSQL_USER" "CLOUDSQL_PASSWORD")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if echo "$ENV_DATA" | grep -q "$var"; then
        print_success "$var is set"
    else
        print_error "$var is MISSING"
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo ""
    print_error "Missing environment variables: ${MISSING_VARS[*]}"
    echo "   Set them with:"
    echo "   gcloud run services update $SERVICE_NAME \\"
    echo "     --region $REGION \\"
    echo "     --update-env-vars \"VAR1=value1,VAR2=value2\""
fi
echo ""

# 4. Check backend logs for database connection errors
print_check "4. Recent backend logs for database errors"
echo "   Checking last 50 log entries..."
LOG_ERRORS=$(gcloud run services logs read $SERVICE_NAME \
  --region $REGION \
  --limit 50 \
  --format="value(textPayload,jsonPayload.message)" 2>/dev/null | \
  grep -i -E "(database|cloudsql|connection|error|failed|timeout)" || echo "")

if [ -z "$LOG_ERRORS" ]; then
    print_warning "No obvious database errors in recent logs"
    echo "   View full logs with:"
    echo "   gcloud run services logs read $SERVICE_NAME --region $REGION --limit 100"
else
    print_error "Found potential database errors in logs:"
    echo "$LOG_ERRORS" | head -10
fi
echo ""

# 5. Test backend database status endpoint
print_check "5. Backend database status endpoint"
BACKEND_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(status.url)' 2>/dev/null)

if [ -n "$BACKEND_URL" ]; then
    print_success "Backend URL: $BACKEND_URL"
    
    # Test /api/db-status endpoint
    DB_STATUS_RESPONSE=$(curl -s "$BACKEND_URL/api/db-status" 2>/dev/null || echo '{"status":"error","message":"Connection failed"}')
    
    if echo "$DB_STATUS_RESPONSE" | grep -q '"status":"connected"'; then
        print_success "Backend reports database is connected"
    elif echo "$DB_STATUS_RESPONSE" | grep -q '"status":"error"'; then
        print_error "Backend reports database connection error"
        echo "   Response: $DB_STATUS_RESPONSE"
    else
        print_warning "Unexpected response from /api/db-status"
        echo "   Response: $DB_STATUS_RESPONSE"
    fi
else
    print_error "Could not get backend URL"
fi
echo ""

# 6. Check if database client is initialized (from logs)
print_check "6. Database client initialization status"
INIT_LOG=$(gcloud run services logs read $SERVICE_NAME \
  --region $REGION \
  --limit 100 \
  --format="value(textPayload,jsonPayload.message)" 2>/dev/null | \
  grep -i -E "(Cloud SQL|database client|db_client|initializing)" || echo "")

if echo "$INIT_LOG" | grep -q -i "Cloud SQL connection successful"; then
    print_success "Database client initialized successfully (from logs)"
elif echo "$INIT_LOG" | grep -q -i "Cloud SQL connection failed"; then
    print_error "Database client initialization FAILED (from logs)"
    echo "   Check initialization errors above"
else
    print_warning "Could not determine initialization status from logs"
fi
echo ""

# 7. Compare environment variables with expected values
print_check "7. Environment variable values verification"
if [ -n "$ENV_DATA" ]; then
    # Extract CLOUDSQL_INSTANCE_CONNECTION_NAME
    INSTANCE_NAME=$(echo "$ENV_DATA" | python3 -c "
import sys, re
data = sys.stdin.read()
match = re.search(r\"\{'name':\s*'CLOUDSQL_INSTANCE_CONNECTION_NAME',\s*'value':\s*'([^']+)'\", data)
print(match.group(1) if match else '')
" 2>/dev/null || echo "")
    
    if [ -n "$INSTANCE_NAME" ]; then
        print_success "CLOUDSQL_INSTANCE_CONNECTION_NAME: $INSTANCE_NAME"
        
        # Check if it matches the annotation
        if [ -n "$CLOUDSQL_ANNOTATION" ] && [ "$CLOUDSQL_ANNOTATION" = "$INSTANCE_NAME" ]; then
            print_success "Environment variable matches Cloud SQL annotation"
        elif [ -n "$CLOUDSQL_ANNOTATION" ]; then
            print_error "Environment variable does NOT match Cloud SQL annotation"
            echo "   Env var: $INSTANCE_NAME"
            echo "   Annotation: $CLOUDSQL_ANNOTATION"
        fi
    else
        print_error "Could not extract CLOUDSQL_INSTANCE_CONNECTION_NAME"
    fi
fi
echo ""

# 8. Check Cloud SQL instance status
print_check "8. Cloud SQL instance status"
if [ -n "$CLOUDSQL_ANNOTATION" ]; then
    INSTANCE_NAME=$(echo "$CLOUDSQL_ANNOTATION" | cut -d',' -f1 | xargs)
    INSTANCE_PROJECT=$(echo "$INSTANCE_NAME" | cut -d':' -f1)
    INSTANCE_REGION=$(echo "$INSTANCE_NAME" | cut -d':' -f2)
    INSTANCE_ID=$(echo "$INSTANCE_NAME" | cut -d':' -f3)
    
    INSTANCE_STATE=$(gcloud sql instances describe $INSTANCE_ID \
      --project $INSTANCE_PROJECT \
      --format='value(state)' 2>/dev/null || echo "UNKNOWN")
    
    if [ "$INSTANCE_STATE" = "RUNNABLE" ]; then
        print_success "Cloud SQL instance is RUNNABLE"
    elif [ "$INSTANCE_STATE" = "UNKNOWN" ]; then
        print_warning "Could not check Cloud SQL instance status"
    else
        print_error "Cloud SQL instance state: $INSTANCE_STATE"
        echo "   Instance must be RUNNABLE for connections to work"
    fi
else
    print_warning "Skipping - Cloud SQL instance not attached"
fi
echo ""

# Summary
echo "======================================================"
echo "📋 Summary"
echo "======================================================"
echo ""

ISSUES=0

if [ -z "$CLOUDSQL_ANNOTATION" ]; then
    echo "❌ Issue 1: Cloud SQL instance not attached to Cloud Run service"
    echo "   This is the MOST COMMON cause of connection failures"
    ISSUES=$((ISSUES + 1))
fi

if [ "$SERVICE_ACCOUNT" != "UNKNOWN" ] && [ -z "$HAS_ROLE" ]; then
    echo "❌ Issue 2: Service account missing Cloud SQL Client permission"
    ISSUES=$((ISSUES + 1))
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Issue 3: Missing environment variables"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ No obvious configuration issues found"
    echo ""
    echo "💡 If queries still fail, check:"
    echo "   1. Backend logs for runtime errors:"
    echo "      gcloud run services logs read $SERVICE_NAME --region $REGION --limit 100"
    echo ""
    echo "   2. Database client initialization in code"
    echo "   3. Network connectivity from Cloud Run to Cloud SQL"
    echo "   4. Database user permissions"
else
    echo ""
    echo "💡 Fix the issues above, then redeploy:"
    echo "   ./scripts/fix_backend_database_connection.sh"
fi
echo ""

