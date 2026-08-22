#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

printf 'БРОДЯГА — GPU/RAM check\n\n'

if command -v nvidia-smi >/dev/null 2>&1; then
  printf 'NVIDIA GPU\n'
  nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free,utilization.gpu \
    --format=csv,noheader
else
  printf '! nvidia-smi not found: GPU driver is unavailable.\n'
fi

printf '\nOllama placement\n'
CONTAINER_ID="$(docker compose -f compose.yaml ps -q ollama 2>/dev/null || true)"
if [[ -n "$CONTAINER_ID" ]]; then
  PS_OUTPUT="$(docker compose -f compose.yaml exec -T ollama ollama ps 2>/dev/null || true)"
  if [[ -n "$PS_OUTPUT" ]]; then
    printf '%s\n' "$PS_OUTPUT"
    if printf '%s\n' "$PS_OUTPUT" | grep -q '100% GPU'; then
      printf '✓ Loaded model is entirely on GPU.\n'
    elif printf '%s\n' "$PS_OUTPUT" | grep -Eq 'CPU|CPU/GPU'; then
      printf '! CPU offload detected: lower the model size or context.\n'
    else
      printf 'No model is loaded. Send one request, then run make memory again.\n'
    fi
  else
    printf 'Ollama is running, but ollama ps returned no data.\n'
  fi

  printf '\nContainer RAM ceilings and current use\n'
  docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' "$CONTAINER_ID"
  WEBUI_ID="$(docker compose -f compose.yaml ps -q open-webui 2>/dev/null || true)"
  if [[ -n "$WEBUI_ID" ]]; then
    docker stats --no-stream --format '{{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' "$WEBUI_ID"
  fi
else
  printf 'Ollama container is not running. Start it with: make rtx3060\n'
fi

printf '\nHost RAM\n'
if command -v free >/dev/null 2>&1; then
  free -h
  printf 'Read the "available" column, not "used": Linux file cache is reclaimable.\n'
elif command -v vm_stat >/dev/null 2>&1; then
  vm_stat | head -8
else
  printf 'No supported host-memory command found.\n'
fi

printf '\nExpected healthy state for RTX 3060 12 GB:\n'
printf '  PROCESSOR = 100%% GPU; one loaded model; context = 16384; parallel = 1.\n'
