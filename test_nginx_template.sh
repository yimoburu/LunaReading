#!/bin/bash
# Test nginx template substitution locally

BACKEND_URL=${1:-"https://lunareading-backend-uc.a.run.app"}

echo "Testing nginx template substitution..."
echo "BACKEND_URL: $BACKEND_URL"
echo ""

if [ ! -f "nginx.conf.template" ]; then
    echo "❌ nginx.conf.template not found"
    exit 1
fi

# Test substitution
export BACKEND_URL
envsubst '$BACKEND_URL' < nginx.conf.template > /tmp/nginx-test.conf

echo "Generated nginx config:"
echo "======================"
grep -A 5 "location /api" /tmp/nginx-test.conf

echo ""
echo "Checking if BACKEND_URL was substituted..."
if grep -q "\${BACKEND_URL}" /tmp/nginx-test.conf; then
    echo "❌ BACKEND_URL was NOT substituted!"
else
    echo "✅ BACKEND_URL was substituted correctly"
fi

