# items-api

Node.js Items API delivered as a production-shaped container: Docker Image → Docker Hub → **Render** (Staging + Production), with GitHub Actions for checks, publish, scan, and Deploy.

**Repository:** https://github.com/DovgiyA/CI-CD-Node.js  
**Staging (Render):** https://items-api-latest.onrender.com  
**Production (Render):** https://items-api-production.onrender.com

## What it is

- **Приложение:** Express + Prisma + Postgres + TypeScript
- **Item:** `id`, `title`, `createdAt`
- **API:** `GET/POST /items`, `GET/PATCH/DELETE /items/:id`, `GET /health`
- Domain language: see [`CONTEXT.md`](./CONTEXT.md)

## Quick start (local)

> If this repo lives in a directory whose name contains `:`, npm’s `PATH` breaks on macOS/Linux. Scripts in `package.json` call binaries via `node ./node_modules/...` so local commands still work; renaming the folder (e.g. `CI-CD-node`) is still a good idea.

```bash
cp .env.example .env
npm ci
docker compose up --build
# API: http://localhost:3000/health
```

Repeatable smoke (health + create/read Item; asserts `DATABASE_URL` is not baked into the Image):

```bash
npm run smoke:compose
```

App-only on the host (Postgres via compose):

```bash
docker compose up -d db
npm ci
npx prisma migrate deploy
npm run dev
```

## Checks

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

## Environment

| Variable       | Required | Notes                                      |
|----------------|----------|--------------------------------------------|
| `PORT`         | no       | Default `3000`; Render injects its own     |
| `DATABASE_URL` | yes      | Postgres connection string                 |
| `NODE_ENV`     | no       | `production` in Image / Render             |

Never put secrets in the Image or git. Set `DATABASE_URL` on Render (link from Free Postgres).

## CI/CD

| Trigger | What happens |
|---------|----------------|
| PR / push (not `main`) | ESLint, Vitest, `tsc`, Prisma validate, CodeQL |
| Push to `main` | Same checks + `npm audit` (critical) → build Image → **Trivy CRITICAL** → push `sha-<commit>` + `latest` to Docker Hub → Deploy **Staging** on Render |
| Tag `v*` or `workflow_dispatch` | Deploy **Production** (GitHub Environment approval) to a pinned Image on Render |

**CodeQL gate:** the analyze job uploads results; GitHub marks the PR **Code scanning** check failed for **error**-severity alerts by default. After the repo exists, enable merge protection / ruleset so unresolved Error (or higher) code-scanning alerts block merge — that is how “CodeQL fails the Pipeline” is enforced (the Action itself does not exit non-zero on findings).

**Migrations:** Render **pre-deploy command** runs `node ./node_modules/prisma/build/index.js migrate deploy` (ADR-0002 intent; ADR-0004 host). Local compose is the only place that migrate-then-starts.

### GitHub secrets / vars

- `DOCKERHUB_USERNAME` — Docker Hub user
- `DOCKERHUB_TOKEN` — access token (push)
- `RENDER_API_KEY` — Render API key
- `RENDER_STAGING_SERVICE_ID` — Staging web service id (`srv-…`)
- `RENDER_PRODUCTION_SERVICE_ID` — Production web service id (ticket 07+)

Docker Hub secrets:

```bash
export DOCKERHUB_USERNAME='…'
export DOCKERHUB_TOKEN='…'
# FLY_API_TOKEN no longer used — keep or delete on GitHub
sh scripts/setup-github-delivery-secrets.sh
```

Render secrets (after bootstrap below):

```bash
export RENDER_API_KEY='rnd_…'
export RENDER_STAGING_SERVICE_ID='srv-…'
# export RENDER_PRODUCTION_SERVICE_ID='srv-…'  # when Production exists
sh scripts/setup-render-secrets.sh
```

### GitHub Environments

Environments **`staging`** and **`production`** (production has required reviewer: repo owner).

### Docker Hub

Public repository: `DOCKERHUB_USERNAME/items-api`  
Tags: `sha-<12-char-sha>` (immutable), `latest` (only from `main`).

## Render setup (once, free — no credit card)

1. Sign up at [render.com](https://render.com) (GitHub login is fine).
2. **New → Postgres** → Free → name e.g. `items-api-db-staging`.
3. **New → Web Service** → **Deploy an existing image from a registry**:
   - Image URL: `docker.io/adolgov321/items-api:latest` (use your Hub user)
   - Instance: **Free**
   - Health check path: `/health`
4. **Environment**:
   - Add `NODE_ENV=production`
   - Add `DATABASE_URL` from the Postgres service (or “Link database”)
5. **Pre-Deploy Command:**
   ```text
   node ./node_modules/prisma/build/index.js migrate deploy
   ```
6. Deploy once from the dashboard (pulls `latest`).
7. Account → API Keys → create key.  
   Service → Settings → copy **Service ID** (`srv-…`).
8. Set GitHub secrets via `scripts/setup-render-secrets.sh`.

Repeat steps 2–6 for Production (`items-api-db-production` / separate web service) when doing ticket 07.

CI Deploys call Render `POST /v1/services/{id}/deploys` with `imageUrl=docker.io/…/items-api:sha-…` (see ADR 0004).

> Free web services sleep after idle; first request may take ~1 minute. Free Postgres expires after 30 days — fine for homework.

### Rollback (Production)

1. Find a prior good tag, e.g. `sha-abc123def456`
2. Actions → **Production deploy** → Run workflow → enter that tag
3. Approve the `production` environment

Migrations are **not** rolled back (ADR 0003). Prefer `sha-…` tags (not raw digests) for Render `imageUrl`.

## Image design

- Multi-stage build, Node 22 bookworm-slim
- `npm ci` + `prisma generate` + `tsc`; runtime `npm prune --omit=dev`
- npm/npx removed from the final Image (smaller + cleaner Trivy surface)
- Non-root user (`nodejs` uid 1001)
- `NODE_ENV=production`, listens on `0.0.0.0:$PORT`

## Non-goals

Explicitly out of scope for this repository:

- Kubernetes / custom cluster orchestration
- Terraform / full IaC beyond Actions + host dashboard/API
- APM, metrics backends, alerting, on-call
- Traffic-percentage canary / blue-green
- Multi-region / self-managed HA Postgres
- CDN, WAF, edge rate limiting
- External secret managers (Vault, etc.) beyond GitHub + Render
- Fly.io (superseded by ADR 0004)

## ADRs

- [0001 — Public Docker Hub](./docs/adr/0001-public-docker-hub.md)
- [0002 — release_command / pre-deploy Migrations](./docs/adr/0002-fly-release-command-migrations.md)
- [0003 — Rollback & forward-only Migrations](./docs/adr/0003-rollback-forward-only-migrations.md)
- [0004 — Render instead of Fly.io](./docs/adr/0004-render-instead-of-fly.md)
