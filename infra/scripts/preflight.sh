#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$REPO_ROOT/infra/ENV_REPORT.md"
echo "# ENV REPORT - $(date)" > "$OUT"

fail=0
check_cmd(){
  echo "- $1: " >> "$OUT"
  if command -v $2 >/dev/null 2>&1; then
    echo "  - OK" >> "$OUT"
  else
    echo "  - MISSING: $2 not found" >> "$OUT"
    fail=1
  fi
}

check_file(){
  echo "- $1: " >> "$OUT"
  if [ -e "$2" ]; then
    echo "  - OK" >> "$OUT"
  else
    echo "  - MISSING: $2" >> "$OUT"
    fail=1
  fi
}

echo "## Binaries" >> "$OUT"

check_cmd "docker" docker
echo "- docker compose: " >> "$OUT"
if docker compose version >/dev/null 2>&1; then
  echo "  - OK" >> "$OUT"
else
  echo "  - MISSING: docker compose subcommand not available" >> "$OUT"
  fail=1
fi
check_cmd "mc (minio client, optional for snapshots)" mc || true

echo "\n## Project layout" >> "$OUT"
check_file "infra/docker-compose.yml" "$REPO_ROOT/infra/docker-compose.yml"
check_file "web folder" "$REPO_ROOT/web"
check_file "api folder" "$REPO_ROOT/api"
check_file "web Dockerfile" "$REPO_ROOT/web/Dockerfile"
check_file "api Dockerfile" "$REPO_ROOT/api/Dockerfile"
check_file "web env example" "$REPO_ROOT/web/.env.example"
check_file "api env example" "$REPO_ROOT/api/.env.example"

echo "\n## Ports (listening checks)" >> "$OUT"
check_port(){
  PORT=$1
  echo "- port $PORT: " >> "$OUT"
  if ss -lnt | awk '{print $4}' | grep -q ":$PORT$"; then
    echo "  - IN USE" >> "$OUT"
  else
    echo "  - FREE" >> "$OUT"
  fi
}

for p in 3000 4000 5432 6379 9000 8025; do
  check_port $p
done

echo "\n## Summary" >> "$OUT"
if [ $fail -ne 0 ]; then
  echo "Some checks failed. See above entries." >> "$OUT"
  echo "Preflight result: FAIL" >> "$OUT"
  exit 1
else
  echo "All required binaries and files present." >> "$OUT"
  echo "Preflight result: PASS" >> "$OUT"
  exit 0
fi
