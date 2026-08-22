#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="${1:-}"
if [[ -z "$MODEL" && -f "$ROOT_DIR/.env" ]]; then
  MODEL="$(awk -F= '$1 == "QWEN_MODEL" {sub(/^[^=]*=/, ""); print; exit}' "$ROOT_DIR/.env")"
fi
MODEL="${MODEL:-qwen3:8b}"

[[ "$MODEL" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*(:[A-Za-z0-9][A-Za-z0-9._-]*)?$ ]] || {
  printf 'Invalid model name: %s\n' "$MODEL" >&2
  exit 2
}

printf 'Testing OpenAI-compatible API with %s...\n' "$MODEL"
RESPONSE="$(curl -fsS --max-time 300 http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: BRODYAGA_OK\"}],\"stream\":false}")"

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESPONSE" | jq -e '.choices[0].message.content | type == "string"' >/dev/null
  printf 'Response: %s\n' "$(printf '%s\n' "$RESPONSE" | jq -r '.choices[0].message.content' | tail -1)"
else
  printf '%s\n' "$RESPONSE" | grep -q '"choices"'
  printf 'API returned a completion. Install jq for readable output.\n'
fi
