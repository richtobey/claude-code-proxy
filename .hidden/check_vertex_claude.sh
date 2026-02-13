#!/usr/bin/env bash
# Check Vertex AI setup and Claude model access for the proxy.
# Run after: gcloud auth application-default login
# Usage: ./check_vertex_claude.sh [PROJECT_ID]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load project/location from .env if present
if [[ -f .env ]]; then
  export $(grep -E '^VERTEX_PROJECT=|^VERTEX_LOCATION=' .env | xargs)
fi

PROJECT_ID="${1:-${VERTEX_PROJECT:-}}"
LOCATION="${VERTEX_LOCATION:-us-central1}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 [PROJECT_ID]"
  echo "  Or set VERTEX_PROJECT in .env"
  echo "  Example: $0 gen-lang-client-0231020876"
  exit 1
fi

echo "=== Vertex AI Claude check ==="
echo "Project: $PROJECT_ID"
echo "Location: $LOCATION"
echo ""

# 1. Ensure Vertex AI API is enabled
echo "1. Enabling Vertex AI API (no-op if already enabled)..."
gcloud services enable aiplatform.googleapis.com --project="$PROJECT_ID"
echo "   Done."
echo ""

# 2. Get token and list Anthropic models (requires valid ADC)
echo "2. Checking Application Default Credentials..."
if ! TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null); then
  echo "   ERROR: Application Default Credentials are missing or expired."
  echo ""
  echo "   Run:"
  echo "     gcloud auth application-default login"
  echo "     gcloud config set project $PROJECT_ID"
  echo ""
  echo "   Then run this script again."
  exit 1
fi
echo "   Token obtained."
echo "   Setting quota project to $PROJECT_ID (required for Vertex AI with user credentials)..."
gcloud auth application-default set-quota-project "$PROJECT_ID" 2>/dev/null || true
echo "   Done."
echo ""

# 3. List Anthropic publisher models in Model Garden
echo "3. Listing Anthropic models in Model Garden (region: $LOCATION)..."
if [[ "$LOCATION" == "global" ]]; then
  URL="https://aiplatform.googleapis.com/v1beta1/publishers/anthropic/models?pageSize=20"
else
  URL="https://${LOCATION}-aiplatform.googleapis.com/v1beta1/publishers/anthropic/models?pageSize=20"
fi
# x-goog-user-project ensures the request uses this project for quota/billing when using user ADC
RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: $PROJECT_ID" "$URL")
# Portable: all but last line (macOS head doesn't support -n -1)
BODY=$(echo "$RESP" | sed '$d')
CODE=$(echo "$RESP" | tail -n 1)

if [[ "$CODE" != "200" ]]; then
  echo "   HTTP $CODE"
  echo "$BODY" | head -20
  echo ""
  if [[ "$CODE" == "401" || "$CODE" == "403" ]]; then
    echo "   Fix: Run 'gcloud auth application-default login', then:"
    echo "        gcloud auth application-default set-quota-project $PROJECT_ID"
    echo "   Ensure your account has Vertex AI access (e.g. Vertex AI User) on project $PROJECT_ID."
  fi
  if [[ "$CODE" == "404" || "$CODE" == "400" ]]; then
    echo "   Tip: For Claude Sonnet 4.5+ you can try VERTEX_LOCATION=global in .env (global endpoint)."
  fi
  exit 1
fi

# Pretty-print model IDs if we have them
if echo "$BODY" | grep -q '"name"'; then
  echo "   Available Anthropic (Claude) models in this project/region:"
  echo "$BODY" | grep -o '"name":"[^"]*"' | sed 's/"name":"/     /;s/"$//' || true
else
  echo "   Response (raw):"
  echo "$BODY" | head -30
fi
echo ""

# 4. Reminder about Model Garden
echo "4. If your model is not listed or you get 'model not found' when using the proxy:"
echo "   - Open Model Garden and enable the Claude model for this project:"
echo "     https://console.cloud.google.com/vertex-ai/model-garden?project=$PROJECT_ID"
echo "   - Search for 'Claude Sonnet 4.5' (or your target model) and click Enable."
echo "   - Use the exact model ID in .env (e.g. BIG_MODEL=claude-sonnet-4-5@20250929)."
echo ""
echo "   For global endpoint (recommended for Sonnet 4.5+): set VERTEX_LOCATION=global in .env."
echo ""
