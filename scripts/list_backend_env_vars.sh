#!/bin/bash
# List all environment variables set in the backend Cloud Run service

set -e

REGION=${1:-"us-central1"}
SERVICE_NAME="lunareading-backend"

echo "🔍 Backend Environment Variables"
echo "================================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo ""

# Check if service exists
if ! gcloud run services describe $SERVICE_NAME --region $REGION &>/dev/null; then
    echo "❌ Service '$SERVICE_NAME' not found in region '$REGION'"
    exit 1
fi

# Get environment variables in value format
ENV_DATA=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].env)' 2>/dev/null)


# Get Cloud SQL instance connection name from environment variable
echo "3. Checking Cloud SQL configuration..."
CLOUDSQL_INSTANCE=$(gcloud run services describe lunareading-backend \
  --region $REGION \
  --format='value(spec.template.spec.containers[0].env[?name==`CLOUDSQL_INSTANCE_CONNECTION_NAME`].value)' 2>/dev/null || echo "")
echo "CLOUDSQL_INSTANCE: $CLOUDSQL_INSTANCE"

if [ -z "$ENV_DATA" ]; then
    echo "   No environment variables found"
    exit 0
fi

# Parse and display
python3 << EOF
import sys
import re

# Parse the format: {'name': 'VAR', 'value': 'val'};{'name': 'VAR2', 'value': 'val2'}
input_data = """$ENV_DATA"""

if not input_data:
    print("   No environment variables found")
    sys.exit(0)

print("📋 Environment Variables:")
print("")

# Use regex to find dict patterns
pattern = r"\{'name':\s*'([^']+)',\s*'value':\s*'([^']*)'\}"
matches = re.findall(pattern, input_data)

if not matches:
    print("   ❌ Could not parse environment variables")
    print(f"   Raw data (first 200 chars): {input_data[:200]}")
    sys.exit(1)

# Group variables by category
db_vars = []
api_vars = []
config_vars = []
other_vars = []

for name, value in matches:
    # Mask sensitive values
    if any(keyword in name.upper() for keyword in ['KEY', 'SECRET', 'PASSWORD', 'TOKEN']):
        display_value = value[:10] + "..." if len(value) > 10 else "***"
    else:
        display_value = value
    
    var_info = {'name': name, 'value': value, 'display': display_value}
    
    if 'CLOUDSQL' in name or 'DATABASE' in name or 'DB' in name or 'SQL' in name:
        db_vars.append(var_info)
    elif 'API_KEY' in name or 'API' in name:
        api_vars.append(var_info)
    elif 'JWT' in name or 'PROJECT' in name or 'TYPE' in name:
        config_vars.append(var_info)
    else:
        other_vars.append(var_info)

# Display grouped variables
if db_vars:
    print("   🗄️  Database Variables:")
    for var in db_vars:
        print(f"      {var['name']:40} = {var['display']}")
    print("")

if api_vars:
    print("   🔑 API Keys:")
    for var in api_vars:
        print(f"      {var['name']:40} = {var['display']}")
    print("")

if config_vars:
    print("   ⚙️  Configuration:")
    for var in config_vars:
        print(f"      {var['name']:40} = {var['display']}")
    print("")

if other_vars:
    print("   📦 Other Variables:")
    for var in other_vars:
        print(f"      {var['name']:40} = {var['display']}")
    print("")

# Summary
total = len(db_vars) + len(api_vars) + len(config_vars) + len(other_vars)
print(f"   Total: {total} environment variables")
EOF

echo ""
echo "💡 To update environment variables:"
echo "   gcloud run services update $SERVICE_NAME \\"
echo "     --region $REGION \\"
echo "     --update-env-vars \"VAR1=value1,VAR2=value2\""
echo ""
echo "💡 To view raw output:"
echo "   gcloud run services describe $SERVICE_NAME \\"
echo "     --region $REGION \\"
echo "     --format='value(spec.template.spec.containers[0].env)'"
echo ""
