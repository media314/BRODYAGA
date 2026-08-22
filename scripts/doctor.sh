#!/usr/bin/env bash
set -u

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WARNINGS=0
FAILURES=0

ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

printf 'БРОДЯГА doctor\n\n'
printf 'Host\n'
ok "OS: $(uname -s) $(uname -m)"
if command -v docker >/dev/null 2>&1; then
  ok "$(docker --version)"
else
  fail 'Docker is not installed'
fi
if docker compose version >/dev/null 2>&1; then
  ok "$(docker compose version)"
else
  fail 'Docker Compose v2 is not available'
fi
if docker info >/dev/null 2>&1; then
  ok 'Docker daemon is running'
else
  fail 'Docker daemon is not responding'
fi

printf '\nConfiguration\n'
if [[ -f "$ROOT_DIR/.env" ]]; then
  ok '.env exists'
else
  warn '.env is absent; bootstrap will create it from .env.example'
fi
if docker compose --env-file "$ROOT_DIR/.env.example" -f "$ROOT_DIR/compose.yaml" config --quiet >/dev/null 2>&1; then
  ok 'CPU Compose configuration is valid'
else
  fail 'CPU Compose configuration is invalid'
fi
if docker compose --env-file "$ROOT_DIR/.env.example" -f "$ROOT_DIR/compose.yaml" -f "$ROOT_DIR/compose.gpu.yaml" config --quiet >/dev/null 2>&1; then
  ok 'GPU Compose configuration is valid'
else
  fail 'GPU Compose configuration is invalid'
fi

printf '\nGPU\n'
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | paste -sd ', ' -)"
  ok "NVIDIA driver sees: $GPU_NAME"
  if docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q nvidia; then
    ok 'Docker exposes the NVIDIA runtime'
  else
    warn 'NVIDIA runtime is not listed by Docker; install/configure Container Toolkit'
  fi
elif [[ "$(uname -s)" == "Darwin" ]]; then
  ok 'macOS detected; use --native for Metal acceleration'
else
  warn 'No working NVIDIA GPU detected; CPU mode is still available'
fi

printf '\nServices\n'
if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  ok 'Ollama API answers on 127.0.0.1:11434'
else
  warn 'Ollama API is not running on 127.0.0.1:11434'
fi
if curl -fsS --max-time 3 http://127.0.0.1:3000/health >/dev/null 2>&1; then
  ok 'Open WebUI answers on 127.0.0.1:3000'
else
  warn 'Open WebUI is not running on 127.0.0.1:3000'
fi
if command -v kimi >/dev/null 2>&1; then
  ok "Kimi Code: $(kimi --version 2>/dev/null | head -1)"
else
  warn 'Kimi Code is not installed (optional: make install-kimi)'
fi

printf '\nResult: %d failure(s), %d warning(s).\n' "$FAILURES" "$WARNINGS"
((FAILURES == 0))
