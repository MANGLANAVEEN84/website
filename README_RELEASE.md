# Release & CI notes

This repository includes GitHub Actions workflows to build and publish Docker images, scan them with Trivy, and deploy to TEST and PROD environments.

Required repository secrets (set in GitHub Settings → Secrets):
- `GITHUB_TOKEN` (provided automatically)
- `TEST_HOST`, `TEST_USER`, `TEST_SSH_PRIVATE_KEY` (optional, for TEST deploy)
- `PROD_HOST`, `PROD_USER`, `PROD_SSH_PRIVATE_KEY` (for manual promote to PROD)

Usage

- CI builds images and pushes to GHCR with tags `ghcr.io/<owner>/ukpath-web:sha-<sha>` and `ghcr.io/<owner>/ukpath-api:sha-<sha>`.
- Use the `Promote — manual promote to PROD` workflow to promote specific image tags to production. This workflow requires the `PROD_*` secrets.
