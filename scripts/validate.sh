#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

printf 'Checking shell syntax...\n'
for script in scripts/*.sh; do
  bash -n "$script"
done

if command -v shellcheck >/dev/null 2>&1; then
  printf 'Running ShellCheck...\n'
  shellcheck scripts/*.sh
else
  printf 'ShellCheck not installed; skipped.\n'
fi

printf 'Checking Compose files...\n'
docker compose --env-file .env.example -f compose.yaml config --quiet
docker compose --env-file .env.example -f compose.yaml -f compose.gpu.yaml config --quiet
docker compose --env-file .env.example -f compose.native.yaml config --quiet
docker compose --env-file profiles/rtx3060-12gb.env.example -f compose.yaml -f compose.gpu.yaml -f compose.memory-limit.yaml config --quiet

printf 'Checking required documentation...\n'
for path in README.md LICENSE docs/cuda.md docs/models.md docs/kimi.md docs/troubleshooting.md docs/references.md profiles/rtx3060-12gb.env.example; do
  [[ -s "$path" ]] || { printf 'Missing or empty: %s\n' "$path" >&2; exit 1; }
done

printf 'Looking for accidentally committed API keys...\n'
if rg -n --hidden --glob '!scripts/validate.sh' --glob '!.git/**' 'sk-[A-Za-z0-9_-]{20,}' .; then
  printf 'Possible API key found. Remove it before committing.\n' >&2
  exit 1
fi

printf 'All static checks passed.\n'
