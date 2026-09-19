#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "Bootstrapping local test environment..."

echo "Waiting for Postgres container to be ready..."
until docker exec -i "$(docker compose ps -q postgres)" pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done

echo "Restoring seed data if present..."
SNAP_DIR="$HERE/../snapshots/seed"
if [ -f "$SNAP_DIR/pg_dump.sql" ]; then
  echo "Restoring Postgres dump..."
  cat "$SNAP_DIR/pg_dump.sql" | docker exec -i "$(docker compose ps -q postgres)" psql -U postgres
fi

if [ -d "$SNAP_DIR/minio" ]; then
  echo "Seeding MinIO buckets..."
  # assumes mc configured and alias local points to MinIO
  mc mb -p local/ukpath || true
  mc cp --recursive "$SNAP_DIR/minio/" local/ukpath || true
fi

echo "Bootstrapping complete."
