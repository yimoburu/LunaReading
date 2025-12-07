#!/bin/bash
# Fix 504 Gateway Timeout issues on Cloud Run backend
# This usually indicates database connection timeouts or app hanging

set -e

REGION=${1:-"us-central1"}
SERVICE_NAME="lunareading-backend"
PROJECT_ID=${2:-"lunareading-app"}

echo "🔧 Fixing 504 Gateway Timeout Issues"
echo "===================================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 1. Check current timeout settings
print_check "1. Current Cloud Run timeout settings"
TIMEOUT=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format='value(spec.template.spec.timeoutSeconds)' 2>/dev/null || echo "N/A")

echo "   Current timeout: ${TIMEOUT}s"
if [ "$TIMEOUT" != "N/A" ] && [ "$TIMEOUT" -lt 300 ]; then
    print_warning "Timeout is less than 300s, database operations may timeout"
    echo "   Increasing timeout to 300s (5 minutes)..."
    gcloud run services update $SERVICE_NAME \
      --region $REGION \
      --timeout 300 \
      --quiet
    print_success "Timeout increased to 300s"
else
    print_success "Timeout is already ${TIMEOUT}s (adequate)"
fi
echo ""

# 2. Check database connection configuration
print_check "2. Database connection configuration"
CLOUDSQL_ADDED=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(spec.template.metadata.annotations."run.googleapis.com/cloudsql-instances")' 2>/dev/null || echo "")

if [ -z "$CLOUDSQL_ADDED" ]; then
    print_error "Cloud SQL instance not attached!"
    echo "   This is likely causing connection timeouts"
    echo "   Getting instance name from environment..."
    
    CLOUDSQL_INSTANCE=$(gcloud run services describe $SERVICE_NAME \
      --region $REGION \
      --format='value(spec.template.spec.containers[0].env)' 2>/dev/null | \
      python3 -c "import sys, re; data=sys.stdin.read(); match=re.search(r\"\{'name':\s*'CLOUDSQL_INSTANCE_CONNECTION_NAME',\s*'value':\s*'([^']+)'\", data); print(match.group(1) if match else '')" || echo "")
    
    if [ -n "$CLOUDSQL_INSTANCE" ]; then
        echo "   Adding Cloud SQL instance: $CLOUDSQL_INSTANCE"
        gcloud run services update $SERVICE_NAME \
          --region $REGION \
          --add-cloudsql-instances $CLOUDSQL_INSTANCE \
          --quiet
        print_success "Cloud SQL instance added"
    else
        print_error "Could not find CLOUDSQL_INSTANCE_CONNECTION_NAME"
    fi
else
    print_success "Cloud SQL instance is attached: $CLOUDSQL_ADDED"
fi
echo ""

# 3. Check service account permissions
print_check "3. Service account Cloud SQL permissions"
SERVICE_ACCOUNT=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format 'value(spec.template.spec.serviceAccountName)' 2>/dev/null || echo "")

if [ -z "$SERVICE_ACCOUNT" ]; then
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format 'value(projectNumber)' 2>/dev/null || echo "")
    if [ -n "$PROJECT_NUMBER" ]; then
        SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    fi
fi

if [ -n "$SERVICE_ACCOUNT" ]; then
    HAS_ROLE=$(gcloud projects get-iam-policy $PROJECT_ID \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT} AND bindings.role:roles/cloudsql.client" \
      --format="value(bindings.role)" 2>/dev/null || echo "")
    
    if [ -z "$HAS_ROLE" ]; then
        print_warning "Service account missing Cloud SQL Client permission"
        echo "   Granting permission..."
        gcloud projects add-iam-policy-binding $PROJECT_ID \
          --member="serviceAccount:${SERVICE_ACCOUNT}" \
          --role="roles/cloudsql.client" \
          --quiet
        print_success "Permission granted"
    else
        print_success "Service account has Cloud SQL Client permission"
    fi
fi
echo ""

# 4. Check for database connection hanging in code
print_check "4. Checking for potential database connection issues"
echo "   Reviewing recent logs for database connection patterns..."

RECENT_LOGS=$(gcloud run services logs read $SERVICE_NAME \
  --region $REGION \
  --limit 20 \
  --format="value(textPayload,jsonPayload.message)" 2>/dev/null || echo "")

DB_CONNECTION_LOGS=$(echo "$RECENT_LOGS" | grep -i -E "(cloud sql|database|connection|initializing|timeout)" || echo "")

if [ -n "$DB_CONNECTION_LOGS" ]; then
    echo "   Found database-related logs:"
    echo "$DB_CONNECTION_LOGS" | head -5 | sed 's/^/      /'
    
    if echo "$DB_CONNECTION_LOGS" | grep -qi "failed\|error\|timeout"; then
        print_error "Database connection errors found in logs"
    fi
else
    print_warning "No database connection logs found (may indicate app is hanging before logging)"
fi
echo ""

# 5. Check CPU and memory allocation
print_check "5. Resource allocation"
CPU=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].resources.limits.cpu)' 2>/dev/null || echo "N/A")
MEMORY=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].resources.limits.memory)' 2>/dev/null || echo "N/A")

echo "   CPU: $CPU"
echo "   Memory: $MEMORY"

if [ "$CPU" != "N/A" ] && [ "$CPU" = "1" ]; then
    print_warning "CPU is limited to 1 (may cause slow database connections)"
    echo "   Consider increasing to 2 for better performance"
fi

if [ "$MEMORY" != "N/A" ]; then
    MEMORY_MB=$(echo "$MEMORY" | sed 's/[^0-9]//g')
    if [ "$MEMORY_MB" -lt 512 ]; then
        print_warning "Memory is less than 512MB (may cause issues)"
    fi
fi
echo ""

# 6. Check gunicorn configuration
print_check "6. Gunicorn timeout settings"
echo "   Checking Dockerfile for gunicorn timeout configuration..."

if [ -f "Dockerfile.backend" ]; then
    GUNICORN_TIMEOUT=$(grep -i "timeout" Dockerfile.backend | grep -o "timeout [0-9]*" | head -1 || echo "")
    if [ -n "$GUNICORN_TIMEOUT" ]; then
        echo "   Found: $GUNICORN_TIMEOUT"
        TIMEOUT_VALUE=$(echo "$GUNICORN_TIMEOUT" | grep -o "[0-9]*")
        if [ "$TIMEOUT_VALUE" -lt 300 ]; then
            print_warning "Gunicorn timeout is $TIMEOUT_VALUE (consider increasing to 300)"
        else
            print_success "Gunicorn timeout is adequate ($TIMEOUT_VALUE)"
        fi
    else
        print_warning "Could not find gunicorn timeout in Dockerfile"
    fi
else
    print_warning "Dockerfile.backend not found"
fi
echo ""

# 7. Recommendations
echo "===================================="
echo "📋 Recommendations"
echo "===================================="
echo ""

echo "The 504 errors indicate requests are timing out. Common causes:"
echo ""
echo "1. Database Connection Timeout:"
echo "   - Cloud SQL instance not attached (check above)"
echo "   - Service account missing permissions (check above)"
echo "   - Database connection hanging during initialization"
echo ""
echo "2. Application Startup Issues:"
echo "   - App hanging during Cloud SQL client initialization"
echo "   - Database connection retry logic causing delays"
echo ""
echo "3. Resource Constraints:"
echo "   - CPU too low (currently: $CPU)"
echo "   - Memory too low (currently: $MEMORY)"
echo ""
echo "💡 Next Steps:"
echo ""
echo "1. Check detailed logs for database connection:"
echo "   gcloud run services logs read $SERVICE_NAME --region $REGION --limit 100 | grep -i 'cloud sql\|database\|connection'"
echo ""
echo "2. Verify database connection in code:"
echo "   - Check if CloudSQLClient initialization is blocking"
echo "   - Consider making database connection lazy (connect on first request)"
echo "   - Add connection timeout settings"
echo ""
echo "3. Test database connection directly:"
echo "   python3 scripts/test_database_direct.py"
echo ""
echo "4. If database connection is the issue, consider:"
echo "   - Making connection non-blocking during app startup"
echo "   - Adding connection retry with exponential backoff"
echo "   - Setting connection timeout limits"
echo ""
echo "5. Redeploy with fixes:"
echo "   ./deploy-no-docker.sh"
echo ""

