#!/bin/bash
# Diagnose why deployed backend server is not responding to HTTP requests

set -e

REGION=${1:-"us-central1"}
SERVICE_NAME="lunareading-backend"
PROJECT_ID=${2:-"lunareading-app"}

echo "🔍 Diagnosing Backend Server Not Responding"
echo "============================================="
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

# 1. Check if service exists
print_check "1. Service existence and status"
SERVICE_INFO=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format='json' 2>/dev/null || echo "{}")

if [ "$SERVICE_INFO" = "{}" ]; then
    print_error "Service '$SERVICE_NAME' not found in region '$REGION'"
    echo "   Deploy the service first:"
    echo "   gcloud run deploy $SERVICE_NAME --source . --region $REGION"
    exit 1
fi

SERVICE_STATUS=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('status', {}).get('conditions', [{}])[-1].get('status', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
SERVICE_URL=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('status', {}).get('url', 'N/A'))" 2>/dev/null || echo "N/A")

if [ "$SERVICE_STATUS" = "True" ]; then
    print_success "Service exists and is active"
    echo "   URL: $SERVICE_URL"
elif [ "$SERVICE_STATUS" = "False" ]; then
    print_error "Service exists but is not ready"
    echo "   Check service conditions below"
else
    print_warning "Service status: $SERVICE_STATUS"
fi
echo ""

# 2. Check service conditions
print_check "2. Service conditions"
CONDITIONS=$(echo "$SERVICE_INFO" | python3 -c "
import sys, json
data = json.load(sys.stdin)
conditions = data.get('status', {}).get('conditions', [])
for cond in conditions:
    print(f\"{cond.get('type', 'Unknown')}: {cond.get('status', 'Unknown')} - {cond.get('message', 'No message')}\")
" 2>/dev/null || echo "")

if [ -n "$CONDITIONS" ]; then
    echo "$CONDITIONS" | while IFS= read -r line; do
        if echo "$line" | grep -q "True"; then
            echo "   ✅ $line"
        elif echo "$line" | grep -q "False"; then
            echo "   ❌ $line"
        else
            echo "   ⚠️  $line"
        fi
    done
else
    print_warning "Could not retrieve service conditions"
fi
echo ""

# 3. Check recent logs for errors
print_check "3. Recent logs (last 50 entries)"
echo "   Checking for startup errors, crashes, or connection issues..."
RECENT_LOGS=$(gcloud run services logs read $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --limit 50 \
  --format="value(textPayload,jsonPayload.message)" 2>/dev/null || echo "")

if [ -z "$RECENT_LOGS" ]; then
    print_warning "No recent logs found"
    echo "   This might indicate the service hasn't started or isn't receiving requests"
else
    # Check for common error patterns
    ERROR_COUNT=$(echo "$RECENT_LOGS" | grep -i -E "(error|exception|failed|crash|timeout|connection refused)" | wc -l | tr -d ' ')
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        print_error "Found $ERROR_COUNT error(s) in recent logs"
        echo ""
        echo "   Recent errors:"
        echo "$RECENT_LOGS" | grep -i -E "(error|exception|failed|crash|timeout)" | head -10 | sed 's/^/      /'
    else
        print_success "No obvious errors in recent logs"
    fi
    
    # Check for startup messages
    STARTUP_COUNT=$(echo "$RECENT_LOGS" | grep -i -E "(starting|listening|running|started|initializing)" | wc -l | tr -d ' ')
    if [ "$STARTUP_COUNT" -gt 0 ]; then
        echo ""
        echo "   Startup messages:"
        echo "$RECENT_LOGS" | grep -i -E "(starting|listening|running|started|initializing)" | head -5 | sed 's/^/      /'
    fi
fi
echo ""

# 4. Check service configuration
print_check "4. Service configuration"
CONTAINER_IMAGE=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('image', 'N/A'))" 2>/dev/null || echo "N/A")
PORT=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('ports', [{}])[0].get('containerPort', 'N/A'))" 2>/dev/null || echo "N/A")
CPU=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('resources', {}).get('limits', {}).get('cpu', 'N/A'))" 2>/dev/null || echo "N/A")
MEMORY=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('resources', {}).get('limits', {}).get('memory', 'N/A'))" 2>/dev/null || echo "N/A")

echo "   Container Image: $CONTAINER_IMAGE"
echo "   Port: $PORT"
echo "   CPU: $CPU"
echo "   Memory: $MEMORY"

# Check if port is set correctly
if [ "$PORT" != "8080" ] && [ "$PORT" != "N/A" ]; then
    print_warning "Port is $PORT (expected 8080 for Cloud Run)"
fi
echo ""

# 5. Check environment variables
print_check "5. Environment variables"
ENV_VARS=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format='value(spec.template.spec.containers[0].env)' 2>/dev/null || echo "")

if [ -z "$ENV_VARS" ]; then
    print_warning "No environment variables found"
else
    REQUIRED_VARS=("CLOUDSQL_INSTANCE_CONNECTION_NAME" "CLOUDSQL_DATABASE" "CLOUDSQL_USER" "CLOUDSQL_PASSWORD")
    for var in "${REQUIRED_VARS[@]}"; do
        if echo "$ENV_VARS" | grep -q "$var"; then
            echo "   ✅ $var is set"
        else
            echo "   ❌ $var is missing"
        fi
    done
fi
echo ""

# 6. Test HTTP connectivity
print_check "6. HTTP connectivity test"
if [ "$SERVICE_URL" != "N/A" ] && [ -n "$SERVICE_URL" ]; then
    echo "   Testing: $SERVICE_URL"
    
    HTTP_CODE=$(curl -s -o /tmp/backend_response.txt -w "%{http_code}" --max-time 10 "$SERVICE_URL/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Backend is responding (HTTP 200)"
        RESPONSE=$(cat /tmp/backend_response.txt | head -c 200)
        echo "   Response: $RESPONSE"
    elif [ "$HTTP_CODE" = "000" ]; then
        print_error "Cannot connect to backend (timeout or connection refused)"
        echo "   Possible causes:"
        echo "      - Service is not running"
        echo "      - Service is crashing on startup"
        echo "      - Network/firewall issues"
        echo "      - Service is in a bad state"
    elif [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ]; then
        print_error "Backend returned HTTP $HTTP_CODE (Bad Gateway/Service Unavailable)"
        echo "   This usually means:"
        echo "      - Service is starting up"
        echo "      - Service is crashing"
        echo "      - Health check is failing"
    else
        print_warning "Backend returned HTTP $HTTP_CODE"
        RESPONSE=$(cat /tmp/backend_response.txt | head -c 200)
        echo "   Response: $RESPONSE"
    fi
else
    print_error "Service URL not available"
fi
echo ""

# 7. Check service revisions
print_check "7. Service revisions"
REVISIONS=$(gcloud run revisions list \
  --service $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format="table(name,status,traffic)" \
  --limit 5 2>/dev/null || echo "")

if [ -n "$REVISIONS" ]; then
    echo "$REVISIONS"
    
    # Check if any revision is active
    ACTIVE_REVISION=$(echo "$REVISIONS" | grep -i "active\|true" | head -1)
    if [ -z "$ACTIVE_REVISION" ]; then
        print_warning "No active revision found"
    fi
else
    print_warning "Could not retrieve revisions"
fi
echo ""

# 8. Check for startup script issues
print_check "8. Startup script and entrypoint"
STARTUP_CMD=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; data=json.load(sys.stdin); cmd=data.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [{}])[0].get('command', []); print(' '.join(cmd) if cmd else 'N/A')" 2>/dev/null || echo "N/A")

if [ "$STARTUP_CMD" != "N/A" ] && [ -n "$STARTUP_CMD" ]; then
    echo "   Command: $STARTUP_CMD"
else
    print_warning "No custom startup command (using default)"
fi

# Check for common startup issues in logs
if [ -n "$RECENT_LOGS" ]; then
    STARTUP_ERRORS=$(echo "$RECENT_LOGS" | grep -i -E "(cannot find|module not found|import error|syntax error|permission denied|port already in use)" | head -5)
    if [ -n "$STARTUP_ERRORS" ]; then
        print_error "Potential startup errors found:"
        echo "$STARTUP_ERRORS" | sed 's/^/      /'
    fi
fi
echo ""

# Summary and recommendations
echo "============================================="
echo "📋 Summary and Recommendations"
echo "============================================="
echo ""

ISSUES=0

if [ "$SERVICE_STATUS" != "True" ]; then
    echo "❌ Issue 1: Service is not in ready state"
    echo "   Fix: Check service conditions and logs above"
    ISSUES=$((ISSUES + 1))
fi

if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" = "502" ] || [ "$HTTP_CODE" = "503" ]; then
    echo "❌ Issue 2: HTTP requests are not reaching the service"
    ISSUES=$((ISSUES + 1))
    
    echo ""
    echo "💡 Recommended actions:"
    echo ""
    echo "1. Check detailed logs:"
    echo "   gcloud run services logs read $SERVICE_NAME --region $REGION --limit 100"
    echo ""
    echo "2. Check if service is crashing on startup:"
    echo "   Look for 'error', 'exception', 'failed' in logs"
    echo ""
    echo "3. Verify startup command is correct:"
    echo "   gcloud run services describe $SERVICE_NAME --region $REGION --format='value(spec.template.spec.containers[0].command)'"
    echo ""
    echo "4. Check if port is correctly configured:"
    echo "   Cloud Run expects the app to listen on PORT environment variable (usually 8080)"
    echo ""
    echo "5. Try redeploying the service:"
    echo "   gcloud run deploy $SERVICE_NAME --source . --region $REGION"
    echo ""
    echo "6. Check service health:"
    echo "   gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.conditions)'"
    echo ""
    echo "7. If using custom Dockerfile, verify:"
    echo "   - EXPOSE directive matches PORT env var"
    echo "   - CMD/ENTRYPOINT starts the server correctly"
    echo "   - Server binds to 0.0.0.0, not localhost"
fi

if [ "$ISSUES" -eq 0 ]; then
    echo "✅ No obvious issues found"
    echo ""
    echo "💡 If service still doesn't respond, check:"
    echo "   1. Application code for runtime errors"
    echo "   2. Database connection issues (if applicable)"
    echo "   3. External service dependencies"
    echo "   4. Resource limits (CPU/memory)"
fi

echo ""

