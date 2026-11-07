#!/usr/bin/env bash
# Contract tests use stubbed Docker/NVIDIA/HTTP, never model weights or a daemon.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/.runtime"
TEST_ROOT="$(mktemp -d "$ROOT/.runtime/lugbaka-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir "$TEST_ROOT/bin"
cat >"$TEST_ROOT/bin/docker" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$CALLS"
case " $* " in
  *' info '*) printf '{"nvidia":{}}\n' ;;
  *' up '*) [[ "${FAIL_UP:-0}" != 1 ]] || exit 17 ;;
  *' ollama show '*) model="${!#}"; [[ -f "$MODEL_STATE/${model//\//_}" ]] || exit 1 ;;
  *' ollama pull '*)
    [[ "${FAIL_PULL:-0}" != 1 ]] || exit 23
    model="${!#}"; touch "$MODEL_STATE/${model//\//_}"
    ;;
esac
SH
cat >"$TEST_ROOT/bin/curl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$TEST_ROOT/bin/nvidia-smi" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *query-gpu*) printf 'Test GPU, %s, %s\n' "${TEST_DRIVER:-580.178.04}" "${TEST_CAP:-8.6}" ;;
  -L) printf 'GPU 0: Test GPU\n' ;;
  *) printf '| NVIDIA-SMI | CUDA Version: %s |\n' "${TEST_CUDA:-13.0}" ;;
esac
SH
chmod +x "$TEST_ROOT/bin/"*
export PATH="$TEST_ROOT/bin:$PATH" NO_COLOR=1
export CALLS="$TEST_ROOT/calls"
export MODEL_STATE="$TEST_ROOT/models"
CASE_NO=0
fixture() {
  CASE_NO=$((CASE_NO+1))
  CASE_DIR="$TEST_ROOT/case-$CASE_NO"
  mkdir "$CASE_DIR"
  cp "$ROOT/lugbaka.sh" "$ROOT/compose.yaml" "$ROOT/compose.gpu.yaml" "$ROOT/.env.example" "$CASE_DIR/"
  rm -rf -- "$MODEL_STATE"
  mkdir "$MODEL_STATE"
  : >"$CALLS"
}
launch() { bash "$CASE_DIR/lugbaka.sh" --no-system-changes --bind 127.0.0.1 "$@" >"$TEST_ROOT/result" 2>&1; }
has() { grep -Fq -- "$1" "$2" || { cat "$TEST_ROOT/result"; printf 'Missing: %s\n' "$1" >&2; exit 1; }; }
absent() { if grep -Fq -- "$1" "$2"; then printf 'Unexpected: %s\n' "$1" >&2; exit 1; fi; }
reject() { if launch "$@"; then printf 'Expected failure: %s\n' "$*" >&2; exit 1; fi; absent 'БРОДЯГА готова:' "$TEST_ROOT/result"; }

fixture
cp "$CASE_DIR/.env.example" "$CASE_DIR/.env"
cat >>"$CASE_DIR/.env" <<'ENV'

PRESERVE_MARKER=keep-me
OLLAMA_CONTEXT_LENGTH=8192
OLLAMA_FLASH_ATTENTION=0
OLLAMA_KV_CACHE_TYPE=f16
WEBUI_AUTH=true # keep authentication
WEBUI_NAME="Team $HOME # local"
ENV
before="$(sha256sum "$CASE_DIR/.env")"
launch --cpu --port 33047 --ollama-port 33447
has 'ollama pull qwen3:8b' "$CALLS"
has 'ollama pull qwen3-vl:8b' "$CALLS"
has 'kimi install' "$CALLS"
has 'http://127.0.0.1:33047' "$TEST_ROOT/result"
[[ "$before" == "$(sha256sum "$CASE_DIR/.env")" ]]
python3 - "$CASE_DIR/.runtime/lugbaka/compose.yaml" <<'PY'
import json, sys
values = json.load(open(sys.argv[1]))['services']['ollama']['environment']
assert values['OLLAMA_CONTEXT_LENGTH'] == '8192'
assert values['OLLAMA_FLASH_ATTENTION'] == '0'
assert values['OLLAMA_KV_CACHE_TYPE'] == 'f16'
webui = json.load(open(sys.argv[1]))['services']['open-webui']['environment']
assert webui['WEBUI_AUTH'] == 'true'
assert webui['WEBUI_NAME'] == 'Team $$HOME # local'
PY
: >"$CALLS"
launch --cpu
[[ "$before" == "$(sha256sum "$CASE_DIR/.env")" ]]
absent 'ollama pull ' "$CALLS"
bash "$CASE_DIR/lugbaka.sh" down >"$TEST_ROOT/result" 2>&1
has ' down' "$CALLS"
absent ' down -v' "$CALLS"
has 'PRESERVE_MARKER=keep-me' "$CASE_DIR/.env"
printf 'PASS: CPU install, both downloads, Kimi, LAN URL, resume, retained data\n'

fixture
launch --cpu --light
has 'ollama pull qwen3:4b' "$CALLS"
has 'ollama pull qwen3-vl:4b' "$CALLS"
printf 'PASS: light model selection\n'

fixture
launch --cpu --skip-models --subnet 10.231.71.0/24
python3 - "$CASE_DIR/.runtime/lugbaka/compose.yaml" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))['networks']['default']['ipam']['config'][0]['subnet'] == '10.231.71.0/24'
PY
reject --cpu --subnet 8.8.8.0/24
reject --cpu --subnet 10.231.71.3/24
printf 'PASS: isolated subnet and invalid subnet rejection\n'

fixture
launch --gpu --skip-models
has 'entrypoint nvidia-smi' "$CALLS"
absent 'ollama pull ' "$CALLS"
has 'kimi install' "$CALLS"
printf 'PASS: NVIDIA 580 / CUDA 13, container probe, skipped weights\n'
bash "$CASE_DIR/lugbaka.sh" gpu-check --no-system-changes >"$TEST_ROOT/result" 2>&1
has 'run --rm --runtime=nvidia --gpus all' "$CALLS"
printf 'PASS: standalone GPU check selects the NVIDIA runtime explicitly\n'

fixture
export TEST_DRIVER=535.1
reject --gpu
has 'слишком стар' "$TEST_ROOT/result"
absent ' up ' "$CALLS"
export TEST_DRIVER=550.90
reject --gpu
has 'нужен драйвер >=580' "$TEST_ROOT/result"
unset TEST_DRIVER
printf 'PASS: rejects old / CUDA-incompatible NVIDIA drivers before launch\n'

fixture
export FAIL_PULL=1
reject --cpu
has 'ollama pull qwen3:8b' "$CALLS"
absent 'ollama pull qwen3-vl:8b' "$CALLS"
unset FAIL_PULL
fixture
export FAIL_UP=1
reject --cpu
absent 'ollama pull ' "$CALLS"
unset FAIL_UP
printf 'PASS: download and startup failures never report success\n'

fixture
reject --cpu --port 0
reject --cpu --port 65536
reject --project '../invalid'
cp "$CASE_DIR/.env.example" "$CASE_DIR/.env"
printf '\nQWEN_MODEL=bad;command\n' >"$CASE_DIR/.env"
reject --cpu
sh "$CASE_DIR/lugbaka.sh" banner >"$TEST_ROOT/result"
has 'LUGBAKA SKRIPT' "$TEST_ROOT/result"
for width in 80 120 160; do
  COLUMNS="$width" sh "$CASE_DIR/lugbaka.sh" banner >"$TEST_ROOT/banner-$width"
  awk -v width="$width" 'length > width {exit 1}' "$TEST_ROOT/banner-$width"
  has 'LUGBAKA SKRIPT' "$TEST_ROOT/banner-$width"
done
printf 'PASS: argument/config validation, sh entry point, ASCII banner\n'
printf 'All LUGBAKA contract checks passed.\n'
