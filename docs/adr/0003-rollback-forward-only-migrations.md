# Rollback is a previous Image; Migrations only move forward

Production Rollback means deploying a previously published Image (`sha-…` tag or `sha256:…` digest) via `workflow_dispatch` (or re-tagging). We do **not** run Prisma migrate down in Production.

**Why:** reverse migrations against live data are rarely safe and are easy to get wrong under pressure. Forward-only Migrations force expand/contract discipline when a Release must be undone: roll back the Image only if the schema remains compatible; otherwise ship a forward fix.

**How:** Production Deploy accepts an explicit Image reference; Staging auto-deploys from `main` and is the rehearsal environment before a Release.

**Rejected:** automatic migrate down on Rollback; equating `git revert` alone with Production recovery without pinning the Image.
