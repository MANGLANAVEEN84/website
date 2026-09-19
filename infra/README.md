# Infra — Local dev & test environment

This folder contains a reproducible local test/dev environment that mirrors the shape of CI/Test environments.

Files:
- `docker-compose.yml` — services: `web`, `api`, `postgres`, `redis`, `minio`, `mailhog`.
- `Makefile` — convenient targets: `up`, `down`, `build`, `logs`, `snapshot`, `restore`, `test`.

Quickstart

1. Start the environment:

```bash
cd infra
make up
```

2. Stop:

```bash
make down
```

3. Snapshot data (creates `snapshots/<timestamp>`):

```bash
make snapshot
```

Notes
- The `web` and `api` services expect sibling `web/` and `api/` folders. In this repo they are placeholders — replace with your actual apps.
- `mc` (MinIO client) is required locally for `Makefile` snapshot/restore `mc cp` commands. You can adjust to use containerized `mc` if preferred.
- Secrets: use `.env.test` files for local environment variables; never commit production secrets.
