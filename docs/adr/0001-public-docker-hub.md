# Use public Docker Hub instead of GHCR

We publish Images to a **public** Docker Hub repository (`DOCKERHUB_USERNAME/items-api`) rather than GitHub Container Registry.

**Why:** the assignment allows either registry; Docker Hub was chosen explicitly for simpler external pulls from Fly without GHCR auth wiring. Public visibility keeps Fly pull configuration minimal for a learning project.

**Trade-off:** the Image filesystem is world-readable. Secrets still never go in the Image (`DATABASE_URL` lives on Fly). For a real product with proprietary code, switch to a private repository and configure Fly registry credentials.

**Rejected:** GHCR (better GitHub-native auth, but extra pull credential setup on Fly for this homework path).
