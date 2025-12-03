#!/bin/bash
# Fix 502 error by updating backend configuration

REGION=${1:-"us-central1"}

echo "🔧 Fixing 502 Error - Backend Configuration"
echo "==========================================="
echo ""

# Get backend URL
BACKEND_URL=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$BACKEND_URL" ]; then
    echo "❌ Backend service not found. Deploy it first:"
    echo "   ./deploy-no-docker.sh lunareading-app $REGION"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"
echo ""

# Fix 1: Update database path to use /tmp (writable in Cloud Run)
echo "1. Updating database path to /tmp (writable in Cloud Run)..."
gcloud run services update lunareading-backend \
  --region $REGION \
  --update-env-vars "SQLALCHEMY_DATABASE_URI=sqlite:////tmp/lunareading.db" \
  --quiet

echo "✅ Database path updated"
echo ""

# Fix 2: Set required environment variables
echo "2. Setting environment variables..."
echo "   (If you haven't set these yet, you'll need to provide them)"
echo ""

# Check if env vars are already set
CURRENT_ENV=$(gcloud run services describe lunareading-backend --region $REGION --format 'value(spec.template.spec.containers[0].env)' 2>/dev/null)

if echo "$CURRENT_ENV" | grep -q "OPENAI_API_KEY"; then
    echo "   ✅ OPENAI_API_KEY is already set"
else
    echo "   ⚠️  OPENAI_API_KEY not set. Set it with:"
    echo "   gcloud run services update lunareading-backend --region $REGION --update-env-vars \"OPENAI_API_KEY=your-key\""
fi

if echo "$CURRENT_ENV" | grep -q "JWT_SECRET_KEY"; then
    echo "   ✅ JWT_SECRET_KEY is already set"
else
    echo "   ⚠️  JWT_SECRET_KEY not set. Generating one..."
    JWT_KEY=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
    gcloud run services update lunareading-backend \
      --region $REGION \
      --update-env-vars "JWT_SECRET_KEY=$JWT_KEY" \
      --quiet
    echo "   ✅ JWT_SECRET_KEY generated and set"
fi

echo ""

# Fix 3: Update frontend to point to backend
echo "3. Updating frontend configuration..."
FRONTEND_URL=$(gcloud run services describe lunareading-frontend --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -n "$FRONTEND_URL" ]; then
    echo "   Frontend URL: $FRONTEND_URL"
    echo "   Setting BACKEND_URL in frontend..."
    gcloud run services update lunareading-frontend \
      --region $REGION \
      --update-env-vars "BACKEND_URL=$BACKEND_URL" \
      --quiet
    echo "   ✅ Frontend configured to use backend at: $BACKEND_URL"
else
    echo "   ⚠️  Frontend not deployed yet"
fi

echo ""
echo "4. Testing backend..."
echo "   Testing health endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Backend is responding (HTTP $HTTP_CODE)"
else
    echo "   ⚠️  Backend returned HTTP $HTTP_CODE"
    echo "   Check logs: gcloud run services logs read lunareading-backend --region $REGION --limit 50"
fi

echo ""
echo "✅ Configuration updated!"
echo ""
echo "📝 Next steps:"
echo "1. If OPENAI_API_KEY is not set, run:"
echo "   gcloud run services update lunareading-backend --region $REGION --update-env-vars \"OPENAI_API_KEY=your-key\""
echo ""
echo "2. Test registration at: $FRONTEND_URL"
echo ""
echo "3. If still getting 502, check logs:"
echo "   gcloud run services logs read lunareading-backend --region $REGION --limit 50"

