#!/bin/sh
# Set GitHub Actions secrets required for Image publish + Fly Deploy (ticket 04).
# Usage (values never committed — pass via env only):
#
#   export DOCKERHUB_USERNAME='your-hub-user'
#   export DOCKERHUB_TOKEN='dckr_pat_…'    # Docker Hub access token (Read/Write/Delete)
#   export FLY_API_TOKEN='fo1_…'           # fly tokens create deploy
#   sh scripts/setup-github-delivery-secrets.sh
#
set -eu

REPO="${GITHUB_REPOSITORY:-DovgiyA/CI-CD-Node.js}"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI required" >&2
  exit 1
fi

: "${DOCKERHUB_USERNAME:?set DOCKERHUB_USERNAME}"
: "${DOCKERHUB_TOKEN:?set DOCKERHUB_TOKEN}"
: "${FLY_API_TOKEN:?set FLY_API_TOKEN}"

# Prefer existing login; otherwise reuse git HTTPS credential as GH_TOKEN
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

printf '%s' "$DOCKERHUB_USERNAME" | gh secret set DOCKERHUB_USERNAME -R "$REPO"
printf '%s' "$DOCKERHUB_TOKEN" | gh secret set DOCKERHUB_TOKEN -R "$REPO"
printf '%s' "$FLY_API_TOKEN" | gh secret set FLY_API_TOKEN -R "$REPO"

echo "Secrets set on $REPO:"
gh secret list -R "$REPO"

echo "Environments:"
gh api "repos/$REPO/environments" --jq '.environments[] | .name'
