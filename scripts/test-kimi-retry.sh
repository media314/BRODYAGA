#!/usr/bin/env bash
# Exercise the generated installer with controlled npm network failures.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/.runtime"
TEST_ROOT="$(mktemp -d "$ROOT/.runtime/kimi-retry.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/repo" "$TEST_ROOT/home" "$TEST_ROOT/cache"
cp "$ROOT/lugbaka.sh" "$ROOT/compose.yaml" "$ROOT/.env.example" "$TEST_ROOT/repo/"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_ROOT/bin/docker"
cp "$TEST_ROOT/bin/docker" "$TEST_ROOT/bin/sleep"
chmod +x "$TEST_ROOT/bin/"*
export PATH="$TEST_ROOT/bin:$PATH"
bash "$TEST_ROOT/repo/lugbaka.sh" status --cpu --bind 127.0.0.1 >"$TEST_ROOT/configure.log" 2>&1
export KIMI_TEST_PREFIX="$TEST_ROOT/prefix" KIMI_TEST_COUNT="$TEST_ROOT/count"
python3 - "$TEST_ROOT" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
entry = (root / 'repo/.runtime/lugbaka/kimi-entry.sh').read_text()
for old, new in [('/opt/kimi', str(root/'prefix')), ('/root/.kimi-code', str(root/'home')), ('/root/.npm', str(root/'cache')), ('/lugbaka/', str(root/'repo/.runtime/lugbaka') + '/')]:
    entry = entry.replace(old, new)
(root/'entry.sh').write_text(entry)
PY
cat >"$TEST_ROOT/bin/node" <<'SH'
#!/usr/bin/env bash
test -f "$KIMI_TEST_PREFIX/.version" || exit 1
cat "$KIMI_TEST_PREFIX/.version"
SH
cat >"$TEST_ROOT/bin/npm" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
count=0
[[ ! -f "$KIMI_TEST_COUNT" ]] || read -r count <"$KIMI_TEST_COUNT"
count=$((count+1)); printf '%s\n' "$count" >"$KIMI_TEST_COUNT"
if [[ "$KIMI_TEST_MODE" == permanent ]]; then printf 'npm error code E404\n' >&2; exit 23; fi
if [[ "$KIMI_TEST_MODE" == offline || "$count" -lt 3 ]]; then printf 'npm error network read ETIMEDOUT\n' >&2; exit 28; fi
mkdir -p "$KIMI_TEST_PREFIX/node_modules/.bin"
printf '2.5.2\n' >"$KIMI_TEST_PREFIX/.version"
printf '#!/usr/bin/env bash\nprintf "2.5.2\\n"\n' >"$KIMI_TEST_PREFIX/node_modules/.bin/kimi"
chmod +x "$KIMI_TEST_PREFIX/node_modules/.bin/kimi"
SH
chmod +x "$TEST_ROOT/bin/node" "$TEST_ROOT/bin/npm"
export KIMI_TEST_MODE=recover
bash "$TEST_ROOT/entry.sh" install >"$TEST_ROOT/result" 2>&1 || { cat "$TEST_ROOT/result"; exit 1; }
[[ "$(cat "$KIMI_TEST_COUNT")" == 3 ]]
[[ -f "$TEST_ROOT/home/config.toml" ]]
bash "$TEST_ROOT/entry.sh" install >"$TEST_ROOT/result" 2>&1
[[ "$(cat "$KIMI_TEST_COUNT")" == 3 ]]
printf 'PASS: two npm timeouts recover; installed Kimi is reused without network\n'
touch "$KIMI_TEST_PREFIX/.lugbaka-install-incomplete"
rm -f -- "$KIMI_TEST_COUNT"
bash "$TEST_ROOT/entry.sh" install >"$TEST_ROOT/result" 2>&1
[[ "$(cat "$KIMI_TEST_COUNT")" == 3 ]]
[[ ! -e "$KIMI_TEST_PREFIX/.lugbaka-install-incomplete" ]]
printf 'PASS: interrupted installation is repaired even when its version file already exists\n'
rm -rf -- "$KIMI_TEST_PREFIX"
rm -f -- "$KIMI_TEST_COUNT"
export KIMI_TEST_MODE=offline
if bash "$TEST_ROOT/entry.sh" install >"$TEST_ROOT/result" 2>&1; then exit 1; else rc=$?; fi
[[ "$rc" == 28 && "$(cat "$KIMI_TEST_COUNT")" == 3 ]]
printf 'PASS: persistent network failure stops after three attempts and preserves exit code\n'
rm -f -- "$KIMI_TEST_COUNT"
export KIMI_TEST_MODE=permanent
if bash "$TEST_ROOT/entry.sh" install >"$TEST_ROOT/result" 2>&1; then exit 1; else rc=$?; fi
[[ "$rc" == 23 && "$(cat "$KIMI_TEST_COUNT")" == 1 ]]
printf 'PASS: permanent npm errors fail immediately without retry\n'
python3 - "$TEST_ROOT/repo/.runtime/lugbaka/compose.yaml" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert any(v == 'kimi-npm-cache:/root/.npm' for v in doc['services']['kimi']['volumes'])
assert 'kimi-npm-cache' in doc['volumes']
PY
printf 'PASS: npm cache and debug logs survive one-off container removal\n'
