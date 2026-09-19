# Web — Quick resume

Steps to resume development quickly after reopening the workspace.

1. Fetch the branch and checkout:

   git fetch
   git checkout dev/resume-quickstart

2. Install Node dependencies (uses lockfile if present):

   cd web
   npm ci

3. Start the frontend dev server:

   npm run dev

4. Optional: bring up local infra (Postgres, Redis, MinIO, API):

   # from repo root
   ./infra/scripts/setup_dev.sh

Notes
- Node version is pinned in `.nvmrc` for reproducible installs.
- If you prefer Docker, use the `infra` Makefile: `cd infra && make up`.
