#!/bin/sh
set -e

# Set default value for BACKEND_URL if not set
if [ -z "$BACKEND_URL" ]; then
    echo "⚠️  WARNING: BACKEND_URL not set, using default"
    export BACKEND_URL="https://lunareading-backend-uc.a.run.app"
fi

echo "=== Nginx Entrypoint with BACKEND_URL ==="
echo "BACKEND_URL=$BACKEND_URL"

# Extract hostname from BACKEND_URL for Host header
# BACKEND_URL format: https://lunareading-backend-xxx-uc.a.run.app
# Extract just the hostname part
BACKEND_HOST=$(echo "$BACKEND_URL" | sed -E 's|https?://([^/]+).*|\1|')
if [ -z "$BACKEND_HOST" ]; then
    echo "⚠️  WARNING: Could not extract BACKEND_HOST, using default"
    BACKEND_HOST="lunareading-backend-uc.a.run.app"
fi
export BACKEND_HOST
echo "BACKEND_HOST=$BACKEND_HOST"

# Export variables so they're available for envsubst
export BACKEND_URL
export BACKEND_HOST

# Manually process the nginx template since we need BACKEND_HOST
# nginx:alpine's entrypoint processes templates automatically, but BACKEND_HOST
# is set here, so we need to process it ourselves
echo "Processing nginx template manually..."
if [ -f /etc/nginx/templates/default.conf.template ]; then
    # Process template with both BACKEND_URL and BACKEND_HOST
    envsubst '$BACKEND_URL $BACKEND_HOST' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
    echo "✅ Template processed"
    
    # Verify substitution worked
    if grep -q '\${BACKEND_URL}' /etc/nginx/conf.d/default.conf 2>/dev/null || grep -q '\${BACKEND_HOST}' /etc/nginx/conf.d/default.conf 2>/dev/null; then
        echo "❌ ERROR: Template variables were not substituted!"
        echo "BACKEND_URL still in config: $(grep -o '\${BACKEND_URL}' /etc/nginx/conf.d/default.conf | head -1 || echo 'not found')"
        echo "BACKEND_HOST still in config: $(grep -o '\${BACKEND_HOST}' /etc/nginx/conf.d/default.conf | head -1 || echo 'not found')"
        exit 1
    else
        echo "✅ All variables substituted successfully"
        PROXY_PASS=$(grep 'proxy_pass' /etc/nginx/conf.d/default.conf | grep -v '^#' | head -1)
        echo "proxy_pass: $PROXY_PASS"
        HOST_HEADER=$(grep 'proxy_set_header Host' /etc/nginx/conf.d/default.conf | grep -v '^#' | head -1)
        echo "Host header: $HOST_HEADER"
    fi
    
    # Remove template file so nginx:alpine's entrypoint doesn't process it again
    # This prevents it from overwriting our processed config
    rm -f /etc/nginx/templates/default.conf.template
    echo "✅ Template file removed (already processed)"
else
    echo "⚠️  Template file not found"
fi

# Test nginx configuration syntax
echo "Testing nginx configuration..."
if nginx -t 2>&1; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ ERROR: Nginx configuration is invalid!"
    exit 1
fi

# Call the original nginx entrypoint
# Template is already processed, so nginx:alpine won't find it to process again
exec /docker-entrypoint.sh "$@"

