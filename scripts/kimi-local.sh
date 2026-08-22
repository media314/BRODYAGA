#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL=""
BASE_URL="http://127.0.0.1:11434/v1"
CONTEXT_SIZE="32768"
TARGET_DIR="."

usage() {
  cat <<'EOF'
Usage: ./scripts/kimi-local.sh [--model NAME] [--base-url URL] [--context TOKENS] [PROJECT_DIR]

Examples:
  ./scripts/kimi-local.sh .
  ./scripts/kimi-local.sh --model qwen3-vl:8b ~/code/my-project
EOF
}

read_env() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$ROOT_DIR/.env"
}

while (($#)); do
  case "$1" in
    --model) MODEL="${2:?--model requires a value}"; shift 2 ;;
    --base-url) BASE_URL="${2:?--base-url requires a value}"; shift 2 ;;
    --context) CONTEXT_SIZE="${2:?--context requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) TARGET_DIR="$1"; shift; break ;;
  esac
done
if (($#)); then
  printf 'Only one project directory may be supplied.\n' >&2
  exit 2
fi

command -v kimi >/dev/null 2>&1 || {
  printf 'Kimi Code is not installed. Run: ./scripts/install-kimi.sh\n' >&2
  exit 1
}

if [[ -z "$MODEL" ]]; then
  if [[ -f "$ROOT_DIR/.env" ]]; then
    MODEL="$(read_env QWEN_MODEL)"
  fi
  MODEL="${MODEL:-qwen3:8b}"
fi

[[ "$MODEL" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*(:[A-Za-z0-9][A-Za-z0-9._-]*)?$ ]] || {
  printf 'Unsafe or invalid model name: %s\n' "$MODEL" >&2
  exit 2
}
[[ "$CONTEXT_SIZE" =~ ^[1-9][0-9]*$ ]] || {
  printf 'Context size must be a positive integer.\n' >&2
  exit 2
}
[[ "$BASE_URL" =~ ^https?://[^[:space:]\"]+$ ]] || {
  printf 'Base URL must be an http(s) URL without spaces.\n' >&2
  exit 2
}
[[ -d "$TARGET_DIR" ]] || {
  printf 'Project directory does not exist: %s\n' "$TARGET_DIR" >&2
  exit 1
}

RUNTIME_HOME="$ROOT_DIR/.runtime/kimi"
mkdir -p "$RUNTIME_HOME"

CAPABILITIES='["thinking", "tool_use"]'
if [[ "$MODEL" == *vl* || "$MODEL" == *VL* ]]; then
  CAPABILITIES='["thinking", "image_in", "tool_use"]'
fi

cat >"$RUNTIME_HOME/config.toml" <<EOF
default_model = "ollama/$MODEL"
default_permission_mode = "manual"
default_plan_mode = false
telemetry = false

[providers.ollama]
type = "openai"
base_url = "$BASE_URL"
api_key = "ollama"

[models."ollama/$MODEL"]
provider = "ollama"
model = "$MODEL"
display_name = "$MODEL · local Ollama"
max_context_size = $CONTEXT_SIZE
capabilities = $CAPABILITIES

[thinking]
enabled = true
keep = "all"

[[permission.rules]]
decision = "deny"
pattern = "Bash(rm -rf*)"
EOF

API_ROOT="${BASE_URL%/v1}"
if ! curl -fsS --max-time 3 "$API_ROOT/api/tags" >/dev/null 2>&1; then
  printf 'Warning: Ollama did not answer at %s. Start the stack first.\n' "$API_ROOT" >&2
fi

cd "$TARGET_DIR"
printf 'Starting Kimi Code with %s via %s\n' "$MODEL" "$BASE_URL"
exec env KIMI_CODE_HOME="$RUNTIME_HOME" kimi -m "ollama/$MODEL"
