#!/usr/bin/env bash
# Integration regression: run only in an explicitly disposable Ubuntu guest.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "${LUGBAKA_TEST_DISPOSABLE:-0}" == 1 && "$EUID" == 0 ]] || {
  printf 'Requires root in a disposable Ubuntu VM/container and LUGBAKA_TEST_DISPOSABLE=1.\n' >&2
  exit 1
}
command -v docker >/dev/null
docker compose version
mkdir -p "$ROOT/.runtime"
TEST_ROOT="$(mktemp -d "$ROOT/.runtime/apt-tests.XXXXXX")"
BAD_LIST=/etc/apt/sources.list.d/lugbaka-test-missing-release.list
BAD_SOURCES=/etc/apt/sources.list.d/lugbaka-test-malformed.sources
BAD_MAX=/etc/apt/sources.list.d/lugbaka-test-max.list
[[ ! -e "$BAD_LIST" && ! -e "$BAD_SOURCES" && ! -e "$BAD_MAX" ]] || exit 1
trap 'rm -f -- "$BAD_LIST" "$BAD_SOURCES" "$BAD_MAX"; rm -rf -- "$TEST_ROOT"' EXIT

# Only the gnupg metapackage is removed; gpg and Ubuntu's archive keyring stay.
dpkg --remove gnupg
printf 'deb https://download.max.ru/linux/deb stable main\n' >"$BAD_MAX"
sha256sum "$BAD_MAX" >"$TEST_ROOT/sources.sha256"
if LC_ALL=C apt-get update >"$TEST_ROOT/system-apt.log" 2>&1; then
  printf 'Expected MAX without its signing key to fail.\n' >&2
  exit 1
fi
grep -F 'download.max.ru' "$TEST_ROOT/system-apt.log"
grep -Ei 'Missing key|NO_PUBKEY|signature verification|not signed' "$TEST_ROOT/system-apt.log"
sh "$ROOT/lugbaka.sh" prepare >"$TEST_ROOT/prepare.log" 2>&1 || {
  cat "$TEST_ROOT/prepare.log" >&2
  exit 1
}
sha256sum --check "$TEST_ROOT/sources.sha256"
dpkg-query -W -f='${Status}\n' gnupg | grep -Fx 'install ok installed'
printf 'PASS: MAX signature failure does not block the installer or change its source\n'

dpkg --remove gnupg
printf 'deb https://download.docker.com/linux/ubuntu lugbaka-missing-release stable\n' >"$BAD_LIST"
sha256sum "$BAD_LIST" >>"$TEST_ROOT/sources.sha256"
if LC_ALL=C apt-get update >"$TEST_ROOT/system-apt.log" 2>&1; then
  printf 'Expected a repository without Release to fail.\n' >&2
  exit 1
fi
grep -F 'does not have a Release file' "$TEST_ROOT/system-apt.log"
sh "$ROOT/lugbaka.sh" prepare >"$TEST_ROOT/prepare.log" 2>&1 || {
  cat "$TEST_ROOT/prepare.log" >&2
  exit 1
}
sha256sum --check "$TEST_ROOT/sources.sha256"
dpkg-query -W -f='${Status}\n' gnupg | grep -Fx 'install ok installed'
printf 'PASS: missing Release does not block signed installer repositories\n'

dpkg --remove gnupg
printf 'This is not a deb822 source stanza\n' >"$BAD_SOURCES"
sha256sum "$BAD_SOURCES" >>"$TEST_ROOT/sources.sha256"
sh "$ROOT/lugbaka.sh" prepare >"$TEST_ROOT/prepare.log" 2>&1 || {
  cat "$TEST_ROOT/prepare.log" >&2
  exit 1
}
sha256sum --check "$TEST_ROOT/sources.sha256"
dpkg-query -W -f='${Status}\n' gnupg | grep -Fx 'install ok installed'
printf 'PASS: malformed unrelated sources are preserved and excluded\n'

engine_before="$(dpkg-query -W -f='${Version}' docker-ce)"
dpkg --remove docker-compose-plugin
sh "$ROOT/lugbaka.sh" prepare >"$TEST_ROOT/prepare.log" 2>&1 || {
  cat "$TEST_ROOT/prepare.log" >&2
  exit 1
}
[[ "$(dpkg-query -W -f='${Version}' docker-ce)" == "$engine_before" ]]
docker compose version
sha256sum --check "$TEST_ROOT/sources.sha256"
printf 'PASS: Compose repair keeps the installed Docker Engine version\n'
