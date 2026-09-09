#!/bin/sh
# Set Render deploy secrets (ticket 06 — host switch).
# Prerequisites: Render account, Free Postgres, Free Web Service pulling docker.io/$DOCKERHUB_USERNAME/items-api
#
#   export RENDER_API_KEY='rnd_…'
#   export RENDER_STAGING_SERVICE_ID='srv-…'
#   # optional for ticket 07+:
#   export RENDER_PRODUCTION_SERVICE_ID='srv-…'
#   sh scripts/setup-render-secrets.sh
#
set -eu
REPO="${GITHUB_REPOSITORY:-DovgiyA/CI-CD-Node.js}"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

: "${RENDER_API_KEY:?set RENDER_API_KEY}"
: "${RENDER_STAGING_SERVICE_ID:?set RENDER_STAGING_SERVICE_ID}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI required" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  if [ -z "${GH_TOKEN:-}" ]; then
    GH_TOKEN=$(git credential fill <<EOF | awk -F= '/^password=/{print substr($0,10)}'
protocol=https
host=github.com
EOF
)
    export GH_TOKEN
  fi
fi

printf '%s' "$RENDER_API_KEY" | gh secret set RENDER_API_KEY -R "$REPO"
printf '%s' "$RENDER_STAGING_SERVICE_ID" | gh secret set RENDER_STAGING_SERVICE_ID -R "$REPO"

if [ -n "${RENDER_PRODUCTION_SERVICE_ID:-}" ]; then
  printf '%s' "$RENDER_PRODUCTION_SERVICE_ID" | gh secret set RENDER_PRODUCTION_SERVICE_ID -R "$REPO"
fi

echo "Secrets set on $REPO:"
gh secret list -R "$REPO"
