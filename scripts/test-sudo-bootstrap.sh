#!/usr/bin/env bash
# Mutates only an explicitly disposable container: never run on a workstation/host.
set -Eeuo pipefail
[[ "${1:-}" == --disposable && "$EUID" == 0 && -f /.dockerenv ]] || {
  printf 'Requires --disposable and root inside a disposable Docker container.\n' >&2
  exit 1
}
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ ! -e /usr/local/bin/docker && ! -e /etc/sudoers.d/brodyaga-qa ]] || exit 1
if id brodyagaqa >/dev/null 2>&1; then exit 1; fi
TEST_ROOT="$(mktemp -d /tmp/brodyaga-sudo.XXXXXX)"
cleanup() {
  rm -f -- /usr/local/bin/docker /etc/sudoers.d/brodyaga-qa
  userdel -r brodyagaqa >/dev/null 2>&1 || :
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT
useradd -m -s /bin/bash brodyagaqa
printf 'brodyagaqa ALL=(root) NOPASSWD: ALL\nDefaults:brodyagaqa env_reset\n' >/etc/sudoers.d/brodyaga-qa
chmod 0440 /etc/sudoers.d/brodyaga-qa
visudo -cf /etc/sudoers.d/brodyaga-qa
cat >/usr/local/bin/docker <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
  *' info '*) ((EUID == 0)) || exit 1; printf '{"nvidia":{}}\n' ;;
  *' config '*) exec /usr/bin/docker "$@" ;;
  *' pull '*) exit 79 ;;
  *' ps '*|*' down '*) printf 'DOCKER_OPERATION_UID=%s\n' "$EUID" ;;
  *) exec /usr/bin/docker "$@" ;;
esac
SH
chmod 0755 /usr/local/bin/docker
chown brodyagaqa:brodyagaqa "$TEST_ROOT"
as_qa() {
  runuser -u brodyagaqa -- env -i HOME=/home/brodyagaqa PATH=/usr/local/bin:/usr/bin:/bin \
    bash -c 'cd /tmp; exec "$@"' _ "$@"
}
for style in cpu nvidia cdi; do
  fixture="$TEST_ROOT/$style space : \${HOME}"
  mkdir -p "$fixture/.runtime/lugbaka"
  cp "$ROOT/lugbaka.sh" "$ROOT/compose.yaml" "$ROOT/compose.gpu.yaml" "$ROOT/.env.example" "$fixture/"
  if [[ "$style" == cpu ]]; then mode=cpu; else mode=gpu; fi
  printf '%s\n' "$mode" >"$fixture/.runtime/lugbaka/mode"
  printf '%s\n' "$style" >"$fixture/.runtime/lugbaka/gpu-style"
  chown -R brodyagaqa:brodyagaqa "$fixture"
  as_qa bash "$fixture/lugbaka.sh" status --bind 127.0.0.1 >"$TEST_ROOT/$style.log" 2>&1 || { cat "$TEST_ROOT/$style.log"; exit 1; }
  grep -F 'DOCKER_OPERATION_UID=0' "$TEST_ROOT/$style.log"
  if grep -E 'variable is not set|invalid spec' "$TEST_ROOT/$style.log"; then exit 1; fi
  printf 'PASS: real sudo env_reset and real Compose, %s\n' "$style"
done

download="$TEST_ROOT/download space"
mkdir "$download"
cp "$ROOT/lugbaka.sh" "$download/"
chown -R brodyagaqa:brodyagaqa "$download"
set +e
as_qa bash "$download/lugbaka.sh" --no-system-changes --cpu --skip-models --skip-kimi --bind 127.0.0.1 >"$TEST_ROOT/standalone.log" 2>&1
rc=$?
set -e
[[ "$rc" == 79 ]] || { cat "$TEST_ROOT/standalone.log"; exit 1; }
[[ -f "$download/BRODYAGA/.runtime/lugbaka/compose.yaml" ]]
cmp "$download/lugbaka.sh" "$download/BRODYAGA/lugbaka.sh"
as_qa bash "$download/lugbaka.sh" status >"$TEST_ROOT/resume.log" 2>&1
as_qa bash "$download/lugbaka.sh" down >"$TEST_ROOT/down.log" 2>&1
grep -F 'DOCKER_OPERATION_UID=0' "$TEST_ROOT/resume.log" "$TEST_ROOT/down.log"
printf 'PASS: real Git clone beside downloaded script, resume/status/down from another cwd\n'
