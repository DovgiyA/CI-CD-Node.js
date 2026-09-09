#!/bin/sh
# Local compose smoke: /health + Item create/read (ticket 02).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

echo "==> docker compose up --build -d"
docker compose up --build -d

echo "==> wait for /health"
i=0
while [ "$i" -lt 60 ]; do
  code=$(curl -s -o /tmp/items-health.json -w "%{http_code}" http://localhost:3000/health || echo 000)
  if [ "$code" = "200" ]; then
    echo "health: $(cat /tmp/items-health.json)"
    break
  fi
  i=$((i + 1))
  sleep 2
done
[ "$code" = "200" ] || {
  echo "health failed (last status=$code)"
  docker compose logs api --tail 100
  exit 1
}

echo "==> create Item"
create=$(curl -s -w "\n%{http_code}" -X POST http://localhost:3000/items \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"compose-smoke\"}")
create_body=$(printf "%s" "$create" | sed '$d')
create_code=$(printf "%s" "$create" | tail -n 1)
echo "POST /items -> $create_code $create_body"
[ "$create_code" = "201" ] || exit 1

id=$(printf "%s" "$create_body" | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>console.log(JSON.parse(s).id))")

echo "==> read Item $id"
get=$(curl -s -w "\n%{http_code}" "http://localhost:3000/items/$id")
get_body=$(printf "%s" "$get" | sed '$d')
get_code=$(printf "%s" "$get" | tail -n 1)
echo "GET /items/:id -> $get_code $get_body"
[ "$get_code" = "200" ] || exit 1

printf "%s" "$get_body" | node -e "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{const j=JSON.parse(s); if(j.title!=='compose-smoke'){console.error('title mismatch'); process.exit(2)}})"

echo "==> Image must not bake DATABASE_URL"
img=$(docker compose images -q api)
if docker image inspect "$img" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -q '^DATABASE_URL='; then
  echo "DATABASE_URL is baked into the Image Config.Env — fail"
  exit 1
fi
echo "Image Env has NODE_ENV/PORT only for app config; DATABASE_URL comes from compose/runtime."

echo "SMOKE_PASS"
