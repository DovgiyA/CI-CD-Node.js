# Run Migrations via Fly release_command

Schema Migrations run as Fly `release_command` (`node ./node_modules/prisma/build/index.js migrate deploy`) before new machines receive traffic — not in the container `CMD`/entrypoint alongside the HTTP server. The runtime Image does not include npm; the CLI is invoked via `node` so Migrations do not depend on a package manager in Production.

**Why:** Migrations are part of a Release, not a side effect of process boot. Entrypoint migrations race when multiple machines start and mix Image responsibilities (web process vs schema change).

**Local exception:** `docker-compose` runs migrate-then-start in one command for a single-node DX loop; Staging/Production on Fly always use `release_command`.

**Rejected:** migrate-on-start in production entrypoint; manual one-off migrate before every deploy (breaks automatic Deploy).
