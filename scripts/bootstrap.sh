#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="auto"
PROFILE="default"
SKIP_MODELS=0

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [--gpu|--cpu|--native] [--light] [--skip-models]

  --gpu          Docker Ollama with all NVIDIA GPUs (Linux/WSL2)
  --cpu          Docker Ollama without GPU passthrough
  --native       Open WebUI in Docker + Ollama installed on the host
  --light        Use qwen3:4b and qwen3-vl:4b
  --skip-models  Start services without downloading models
EOF
}

while (($#)); do
  case "$1" in
    --gpu|--cpu|--native) MODE="${1#--}" ;;
    --light) PROFILE="light" ;;
    --skip-models) SKIP_MODELS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v docker >/dev/null 2>&1 || {
  printf 'Docker is not installed. See https://docs.docker.com/engine/install/\n' >&2
  exit 1
}
docker compose version >/dev/null 2>&1 || {
  printf 'Docker Compose v2 is required.\n' >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  printf 'Docker daemon is not available. Start Docker and retry.\n' >&2
  exit 1
}

cd "$ROOT_DIR"
if [[ ! -f .env ]]; then
  cp .env.example .env
  printf 'Created %s/.env\n' "$ROOT_DIR"
fi

set_env_value() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/brodyaga-env.XXXXXX")"
  awk -F= -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    $1 == key { print key "=" value; found = 1; next }
    { print }
    END { if (!found) print key "=" value }
  ' .env >"$tmp"
  mv "$tmp" .env
}

if [[ "$PROFILE" == "light" ]]; then
  set_env_value QWEN_MODEL qwen3:4b
  set_env_value VLM_MODEL qwen3-vl:4b
  printf 'Selected light model profile (4B + 4B).\n'
fi

if [[ "$MODE" == "auto" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]] && command -v ollama >/dev/null 2>&1; then
    MODE="native"
  elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    MODE="gpu"
  else
    MODE="cpu"
  fi
  printf 'Auto-selected mode: %s\n' "$MODE"
fi

case "$MODE" in
  gpu)
    if ! command -v nvidia-smi >/dev/null 2>&1; then
      printf 'nvidia-smi is missing. Install the NVIDIA driver first: docs/cuda.md\n' >&2
      exit 1
    fi
    docker compose -f compose.yaml -f compose.gpu.yaml up -d
    ;;
  cpu)
    docker compose -f compose.yaml up -d
    ;;
  native)
    command -v ollama >/dev/null 2>&1 || {
      printf 'Native mode requires Ollama on the host: https://ollama.com/download\n' >&2
      exit 1
    }
    if ! curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null; then
      printf 'Ollama API is not responding. Start it with: ollama serve\n' >&2
      exit 1
    fi
    docker compose -f compose.native.yaml up -d
    ;;
esac

if ((SKIP_MODELS == 0)); then
  if [[ "$MODE" == "native" ]]; then
    ./scripts/pull-models.sh --native
  else
    ./scripts/pull-models.sh
  fi
fi

printf '\nБРОДЯГА запущена: http://localhost:%s\n' "$(awk -F= '$1 == "WEBUI_PORT" {print $2}' .env | tail -1)"
printf 'Диагностика: ./scripts/doctor.sh\n'
