#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
echo "Setting up dev environment from $ROOT"

# 1) Ensure web deps
if [ -d "$ROOT/../web" ]; then
  echo "Installing web dependencies (npm ci)..."
  cd "$ROOT/../web"
  if [ -f package-lock.json ]; then
    npm ci
  else
    npm install
  fi
else
  echo "warning: web folder not found"
fi

# 2) Ensure .env.test files exist
for f in "$ROOT/../web/.env.test" "$ROOT/../api/.env.test"; do
  if [ ! -f "$f" ]; then
    echo "Creating missing $f from .env.example"
    if [ -f "${f%.test}.example" ]; then
      cp "${f%.test}.example" "$f"
    else
      touch "$f"
    fi
  fi
done

echo "Dev setup complete. Start web dev with: (cd web && npm run dev)"
