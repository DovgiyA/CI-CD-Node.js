# items-api

Node.js Items API delivered as a production-shaped container: Docker Image → Docker Hub → Fly.io (Staging + Production), with GitHub Actions for checks, publish, scan, and Deploy.

**Repository:** https://github.com/DovgiyA/CI-CD-Node.js

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

| Variable       | Required | Notes                          |
|----------------|----------|--------------------------------|
| `PORT`         | no       | Default `3000`                 |
| `DATABASE_URL` | yes      | Postgres connection string     |
| `NODE_ENV`     | no       | `production` in Image / Fly    |

Never put secrets in the Image or git. Set `DATABASE_URL` on Fly (usually via `fly postgres attach`).

## CI/CD

| Trigger | What happens |
|---------|----------------|
| PR / push (not `main`) | ESLint, Vitest, `tsc`, Prisma validate, CodeQL |
| Push to `main` | Same checks + `npm audit` (critical) → build Image → **Trivy CRITICAL** → push `sha-<commit>` + `latest` to Docker Hub → Deploy **Staging** |
| Tag `v*` or `workflow_dispatch` | Deploy **Production** (GitHub Environment approval) to a pinned Image |

**CodeQL gate:** the analyze job uploads results; GitHub marks the PR **Code scanning** check failed for **error**-severity alerts by default. After the repo exists, enable merge protection / ruleset so unresolved Error (or higher) code-scanning alerts block merge — that is how “CodeQL fails the Pipeline” is enforced (the Action itself does not exit non-zero on findings).

**Fly Migrations:** `release_command = "npm run prisma:migrate"` (`prisma migrate deploy`) on Staging and Production (ADR-0002). Local compose is the only place that migrate-then-starts.

### GitHub secrets / vars

- `DOCKERHUB_USERNAME` — Docker Hub user
- `DOCKERHUB_TOKEN` — access token (push)
- `FLY_API_TOKEN` — deploy token

Set them without putting values in git:

```bash
export DOCKERHUB_USERNAME='…'
export DOCKERHUB_TOKEN='…'
export FLY_API_TOKEN='…'
sh scripts/setup-github-delivery-secrets.sh
```

### GitHub Environments

Create **`staging`** and **`production`**. On `production`, enable required reviewers.

This repo is configured with Environments **`staging`** (no reviewers) and **`production`** (required reviewer: repo owner). Admins may still bypass on public repos unless org policy forbids it — keep `prevent_self_review` off for solo homework so you can approve your own Production Deploys.

### Docker Hub

Public repository: `DOCKERHUB_USERNAME/items-api`  
Tags: `sha-<12-char-sha>` (immutable), `latest` (only from `main`).

## Fly.io setup (once)

```bash
# Apps
fly apps create items-api-staging
fly apps create items-api-production

# Postgres (one per environment)
fly postgres create --name items-api-db-staging --region fra
fly postgres create --name items-api-db-production --region fra
fly postgres attach items-api-db-staging -a items-api-staging
fly postgres attach items-api-db-production -a items-api-production
```

Deploys are driven by Actions (`fly deploy --config fly.*.toml --image …`).  
Migrations: `release_command = "npm run prisma:migrate"` (see ADR 0002).

### Rollback (Production)

1. Find a prior good tag, e.g. `sha-abc123def456`
2. Actions → **Production deploy** → Run workflow → enter that tag (or `sha256:…`)
3. Approve the `production` environment

Migrations are **not** rolled back (ADR 0003).

## Image design

- Multi-stage build, Node 22 bookworm-slim
- `npm ci` + `prisma generate` + `tsc`; runtime `npm prune --omit=dev`
- Non-root user (`nodejs` uid 1001)
- `NODE_ENV=production`, listens on `0.0.0.0:$PORT`

## Non-goals

Explicitly out of scope for this repository:

- Kubernetes / custom cluster orchestration
- Terraform / full IaC beyond Fly TOML + Actions
- APM, metrics backends, alerting, on-call
- Traffic-percentage canary / blue-green
- Multi-region / self-managed HA Postgres
- CDN, WAF, edge rate limiting
- External secret managers (Vault, etc.) beyond GitHub + Fly secrets

## ADRs

- [0001 — Public Docker Hub](./docs/adr/0001-public-docker-hub.md)
- [0002 — Fly release_command Migrations](./docs/adr/0002-fly-release-command-migrations.md)
- [0003 — Rollback & forward-only Migrations](./docs/adr/0003-rollback-forward-only-migrations.md)
