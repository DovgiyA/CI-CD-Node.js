# Run Migrations as a Release step (not process boot)

Schema Migrations run as a host **Release / pre-deploy** step  
(`node ./node_modules/prisma/build/index.js migrate deploy`) before new instances receive traffic — not in the container `CMD`/entrypoint alongside the HTTP server. The runtime Image does not include npm; the CLI is invoked via `node`.

**Why:** Migrations are part of a Release, not a side effect of process boot. Entrypoint migrations race when multiple machines start and mix Image responsibilities (web process vs schema change).

**Hosts:**
- **Render (current):** Pre-Deploy Command (ADR-0004)
- **Fly.io (superseded):** `release_command` (same CLI string)

**Local exception:** `docker-compose` runs migrate-then-start in one command for a single-node DX loop.

**Rejected:** migrate-on-start in production entrypoint; manual one-off migrate before every deploy (breaks automatic Deploy).
