# Deploy on Render instead of Fly.io

We Deploy Images from Docker Hub to **Render** (free web service + free Postgres) rather than Fly.io.

**Why:** Fly.org creation now requires a payment method for this account. Render’s free tier does not require a credit card and still supports pulling a prebuilt Image from a registry, a pre-deploy Migration command, Staging/Production as separate services, and API-triggered Deploys of a specific Image tag.

**How Migrations run:** Render **pre-deploy command**  
`node ./node_modules/prisma/build/index.js migrate deploy`  
(same CLI invocation as before; not in the Image `CMD`). This preserves ADR-0002’s intent (Migrations as part of Release, not process boot) on the new host.

**How CI Deploys:** After publishing `sha-…` to Docker Hub, GitHub Actions calls Render  
`POST /v1/services/{id}/deploys` with `imageUrl` set to that tag.

**Rejected for this homework path:** staying on Fly without billing; Railway as primary (trial credits are thinner for always-on Staging + Postgres homework demos).

**Supersedes operational Fly-specific steps** in earlier README; Fly TOML files are removed.
