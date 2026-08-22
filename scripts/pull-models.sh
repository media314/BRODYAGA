#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE=0

if [[ "${1:-}" == "--native" ]]; then
  NATIVE=1
  shift
fi
if (($#)); then
  printf 'Usage: ./scripts/pull-models.sh [--native]\n' >&2
  exit 2
fi

read_env() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$ROOT_DIR/.env"
}

if [[ ! -f "$ROOT_DIR/.env" && ( -z "${QWEN_MODEL:-}" || -z "${VLM_MODEL:-}" ) ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
fi
QWEN_MODEL="${QWEN_MODEL:-$(read_env QWEN_MODEL)}"
VLM_MODEL="${VLM_MODEL:-$(read_env VLM_MODEL)}"

validate_model() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*(:[A-Za-z0-9][A-Za-z0-9._-]*)?$ ]] || {
    printf 'Unsafe or invalid model name: %s\n' "$1" >&2
    exit 2
  }
}
validate_model "$QWEN_MODEL"
validate_model "$VLM_MODEL"

pull_native() {
  command -v ollama >/dev/null 2>&1 || {
    printf 'ollama command not found.\n' >&2
    exit 1
  }
  ollama pull "$1"
}

pull_container() {
  local model="$1" attempt
  cd "$ROOT_DIR"
  for ((attempt = 1; attempt <= 30; attempt++)); do
    if docker compose -f compose.yaml exec -T ollama ollama list >/dev/null 2>&1; then
      docker compose -f compose.yaml exec -T ollama ollama pull "$model"
      return
    fi
    sleep 2
  done
  printf 'Ollama container did not become ready. Run: make logs\n' >&2
  exit 1
}

for model in "$QWEN_MODEL" "$VLM_MODEL"; do
  printf '\n==> Pulling %s\n' "$model"
  if ((NATIVE)); then
    pull_native "$model"
  else
    pull_container "$model"
  fi
done

printf '\nModels are ready: %s, %s\n' "$QWEN_MODEL" "$VLM_MODEL"
