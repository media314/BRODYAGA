#!/usr/bin/env bash
# Use the real Compose parser with a cleared environment; no Docker daemon needed.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_DOCKER="$(command -v docker)"
mkdir -p "$ROOT/.runtime"
TEST_ROOT="$(mktemp -d "$ROOT/.runtime/compose-paths.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/elsewhere"
printf '#!/usr/bin/env bash\nset -Eeuo pipefail\nREAL_DOCKER=%q\n' "$REAL_DOCKER" >"$TEST_ROOT/bin/docker"
cat >>"$TEST_ROOT/bin/docker" <<'SH'
case " $* " in
  *' info '*) printf '{"nvidia":{}}\n' ;;
  *' config '*)
    args=()
    for arg in "$@"; do
      [[ "$arg" != config ]] || args+=(--profile tools)
      [[ "$arg" == --quiet ]] || args+=("$arg")
    done
    env -i PATH=/usr/bin:/bin HOME=/tmp "$REAL_DOCKER" "${args[@]}" --format json >"$RENDERED"
    ;;
  *' ps '*) exit 0 ;;
  *) printf 'Unexpected Docker operation: %s\n' "$*" >&2; exit 1 ;;
esac
SH
chmod +x "$TEST_ROOT/bin/docker"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_ROOT/bin/kimi"
cp "$TEST_ROOT/bin/kimi" "$TEST_ROOT/bin/curl"
chmod +x "$TEST_ROOT/bin/kimi" "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH"
for style in cpu nvidia cdi; do
  CASE_DIR="$TEST_ROOT/$style repo 'quotes' : \${HOME}"
  mkdir -p "$CASE_DIR/.runtime/lugbaka"
  cp "$ROOT/lugbaka.sh" "$ROOT/compose.yaml" "$ROOT/compose.gpu.yaml" "$ROOT/.env.example" "$CASE_DIR/"
  printf '%s\n' "$style" >"$CASE_DIR/.runtime/lugbaka/gpu-style"
  if [[ "$style" == cpu ]]; then mode=cpu; else mode=gpu; fi
  printf '%s\n' "$mode" >"$CASE_DIR/.runtime/lugbaka/mode"
  export RENDERED="$TEST_ROOT/$style.json"
  (
    cd "$TEST_ROOT/elsewhere"
    WEBUI_PORT=9 OLLAMA_IMAGE=invalid LUGBAKA_RUNTIME_DIR=/wrong LUGBAKA_PROJECT_DIR=/wrong \
      bash "$CASE_DIR/lugbaka.sh" status --bind 127.0.0.1 --port 33047 --ollama-port 33447
  ) >"$TEST_ROOT/$style.log" 2>&1 || { cat "$TEST_ROOT/$style.log" >&2; exit 1; }
  python3 - "$RENDERED" "$CASE_DIR" "$style" <<'PY'
import json, pathlib, sys
doc = json.load(open(sys.argv[1]))
root = str(pathlib.Path(sys.argv[2]).resolve())
mounts = {v['target']: v['source'].replace('$$', '$') for v in doc['services']['kimi']['volumes'] if v['type'] == 'bind'}
# Compose config re-escapes literal dollars when serializing its model.
assert mounts['/lugbaka'] == root + '/.runtime/lugbaka', mounts
assert mounts['/workspace'] == root, mounts
assert doc['services']['ollama']['image'] == 'ollama/ollama:0.32.15'
assert doc['services']['open-webui']['ports'][0]['published'] == '33047'
assert doc['services']['ollama']['ports'][0]['published'] == '33447'
assert not pathlib.Path(root, '.env').exists(), 'fresh install must not require/create an env file'
if sys.argv[3] == 'nvidia':
    assert doc['services']['ollama']['runtime'] == 'nvidia'
    assert doc['services']['ollama']['deploy']['resources']['reservations']['devices'][0]['driver'] == 'nvidia'
elif sys.argv[3] == 'cdi':
    assert doc['services']['ollama']['devices'][0]['source'] == 'nvidia.com/gpu=all'
PY
  printf 'PASS: %s paths and ports survive env -i, special characters and another cwd\n' "$style"
  mkdir -p "$CASE_DIR/scripts"
  cp "$ROOT/scripts/kimi-local.sh" "$CASE_DIR/scripts/"
  (cd "$TEST_ROOT/elsewhere"; bash "$CASE_DIR/scripts/kimi-local.sh") >"$TEST_ROOT/kimi.log" 2>&1
  python3 - "$CASE_DIR/.runtime/kimi/config.toml" <<'PY'
import sys, tomllib
config = tomllib.load(open(sys.argv[1], 'rb'))
assert config['providers']['ollama']['base_url'] == 'http://127.0.0.1:33447/v1'
assert config['default_permission_mode'] == 'manual'
PY
  printf 'PASS: native Kimi discovers the saved Ollama port and repository from another cwd\n'
done

before="$(sha256sum "$CASE_DIR/.runtime/lugbaka/settings.json" "$CASE_DIR/.runtime/lugbaka/compose.yaml")"
export RENDERED="$TEST_ROOT/qa.json"
bash "$CASE_DIR/lugbaka.sh" status --cpu --qa-id isolation-test >"$TEST_ROOT/qa.log" 2>&1 || { cat "$TEST_ROOT/qa.log"; exit 1; }
[[ "$before" == "$(sha256sum "$CASE_DIR/.runtime/lugbaka/settings.json" "$CASE_DIR/.runtime/lugbaka/compose.yaml")" ]]
python3 - "$RENDERED" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc['name'] == 'lugbaka-qa-isolation-test'
service = doc['services']['open-webui']
assert service['ports'][0]['host_ip'] == '127.0.0.1'
assert service['ports'][0]['published'] != '3000'
assert service['environment']['CORS_ALLOW_ORIGIN'] != '*'
assert all(v['type'] == 'bind' for s in doc['services'].values() for v in s['volumes'])
PY
printf 'PASS: QA isolates project, state, data and ports while preserving normal configuration\n'

printf '#!/usr/bin/env bash\nprintf "1.1.1.1 dev eth0 src 192.168.50.20\\n"\n' >"$TEST_ROOT/bin/ip"
chmod +x "$TEST_ROOT/bin/ip"
wildcard="$TEST_ROOT/wildcard"
mkdir "$wildcard"
cp "$ROOT/lugbaka.sh" "$ROOT/compose.yaml" "$ROOT/.env.example" "$wildcard/"
export RENDERED="$TEST_ROOT/wildcard.json"
bash "$wildcard/lugbaka.sh" status --cpu --bind 0.0.0.0 --port 80 >"$TEST_ROOT/wildcard.log" 2>&1 || { cat "$TEST_ROOT/wildcard.log"; exit 1; }
python3 - "$RENDERED" <<'PY'
import json, sys
env = json.load(open(sys.argv[1]))['services']['open-webui']['environment']
assert env['WEBUI_URL'] == 'http://192.168.50.20'
assert set(env['CORS_ALLOW_ORIGIN'].split(';')) == {'http://192.168.50.20', 'http://127.0.0.1', 'http://localhost'}
PY
printf 'PASS: wildcard bind and default HTTP port advertise browser-normalized LAN origins\n'
