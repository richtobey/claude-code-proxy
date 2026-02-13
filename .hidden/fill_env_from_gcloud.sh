#!/usr/bin/env bash
#
# Fill .env Vertex variables from gcloud CLI (project, optional credentials path).
# Run from repo root. Safe to run multiple times.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
ENV_FILE="${1:-$REPO_ROOT/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "No .env found at $ENV_FILE. Copy .env.vertex.example to .env first."
    exit 1
fi

if ! command -v gcloud &>/dev/null; then
    echo "Error: gcloud CLI not found."
    exit 1
fi

PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: No gcloud project set. Run: gcloud config set project PROJECT_ID"
    exit 1
fi

# Optional: credentials path from env or default key in repo
CREDS_PATH="${GOOGLE_APPLICATION_CREDENTIALS:-}"
if [[ -z "$CREDS_PATH" ]] && [[ -f "$REPO_ROOT/claude-code-proxy-key.json" ]]; then
    CREDS_PATH="$REPO_ROOT/claude-code-proxy-key.json"
fi
if [[ -z "$CREDS_PATH" ]]; then
    CREDS_PATH="/absolute/path/to/service-account.json"
fi
# Resolve to absolute path if it's a file that exists
if [[ -f "$CREDS_PATH" ]]; then
    CREDS_PATH="$(cd "$(dirname "$CREDS_PATH")" && pwd)/$(basename "$CREDS_PATH")"
fi

echo "Setting in $ENV_FILE:"
echo "  VERTEX_PROJECT=$PROJECT_ID"
echo "  VERTEX_CREDENTIALS_PATH=$CREDS_PATH"

# Update in place: replace only the value part after first =
# Use a temp file to avoid sed portability issues and in-place overwrite
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r line; do
    if [[ "$line" =~ ^VERTEX_PROJECT= ]]; then
        echo "VERTEX_PROJECT=\"$PROJECT_ID\""
    elif [[ "$line" =~ ^VERTEX_CREDENTIALS_PATH= ]]; then
        echo "VERTEX_CREDENTIALS_PATH=\"$CREDS_PATH\""
    else
        echo "$line"
    fi
done < "$ENV_FILE" > "$tmp"
mv "$tmp" "$ENV_FILE"

echo "Done."
