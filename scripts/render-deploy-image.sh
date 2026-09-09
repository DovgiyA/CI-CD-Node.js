#!/bin/sh
# Trigger a Render deploy of a specific Docker Hub Image tag via Public API.
# Usage: IMAGE_URL=docker.io/user/items-api:sha-… SERVICE_ID=srv-… RENDER_API_KEY=… sh scripts/render-deploy-image.sh
set -eu

: "${RENDER_API_KEY:?}"
: "${SERVICE_ID:?}"
: "${IMAGE_URL:?}"

echo "Deploying $IMAGE_URL -> service $SERVICE_ID"

resp=$(curl -sS -X POST "https://api.render.com/v1/services/${SERVICE_ID}/deploys" \
  -H "Authorization: Bearer ${RENDER_API_KEY}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{\"imageUrl\":\"${IMAGE_URL}\"}" \
  -w "\n%{http_code}")

body=$(printf '%s' "$resp" | sed '$d')
code=$(printf '%s' "$resp" | tail -n 1)

echo "$body"
echo "HTTP $code"

case "$code" in
  201|202) ;;
  *) exit 1 ;;
esac
