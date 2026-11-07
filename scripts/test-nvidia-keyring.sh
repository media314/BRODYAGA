#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${1:-}" == --disposable && "$EUID" == 0 && -e /.dockerenv ]] || {
  printf 'Requires --disposable and root inside a disposable Docker container.\n' >&2
  exit 1
}
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script="${2:-$ROOT/lugbaka.sh}"
key=/usr/share/keyrings/lugbaka-nvidia.gpg
source_list=/etc/apt/sources.list.d/lugbaka-nvidia.list
[[ ! -e "$key" && ! -e "$source_list" ]] || exit 1
test_root="$(mktemp -d /tmp/brodyaga-keyring.XXXXXX)"
trap 'rm -f -- "$key" "$source_list" /etc/cdi/lugbaka-nvidia.yaml; rm -rf -- "$test_root"' EXIT
chmod 0755 "$test_root"
mkdir "$test_root/bin" "$test_root/lists"
chmod 0755 "$test_root/lists"
cat >"$test_root/bin/docker-probe" <<'SH'
#!/usr/bin/env bash
case "$*" in *Runtimes*) printf '{}\n' ;; *) printf '29.8.0\n' ;; esac
SH
chmod +x "$test_root/bin/docker-probe"
export PATH="$test_root/bin:$PATH"
# These globals are consumed by the imported production function.
# shellcheck disable=SC2034
AS_ROOT=()
# shellcheck disable=SC2034
DOCKER=("$test_root/bin/docker-probe")
# shellcheck disable=SC2034
NO_SYSTEM_CHANGES=0
root_access() { :; }
driver_check() { :; }
die() { printf '%s\n' "$*" >&2; exit 1; }
https() { curl -fsSL --connect-timeout 10 --max-time 30 "$@"; }
apt_update() {
  runuser -u _apt -- test -r "$key" || { printf 'FAIL: archive verifier cannot read NVIDIA key\n' >&2; return 94; }
  apt-get -o "Dir::Etc::sourcelist=$source_list" -o Dir::Etc::sourceparts=- -o "Dir::State::lists=$test_root/lists" -o Dir::Cache::pkgcache= -o APT::Update::Error-Mode=any update
}
apt_install() {
  cat >"$test_root/bin/nvidia-ctk" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ "$arg" == --output=* ]]; then printf 'cdiVersion: 0.6.0\nkind: nvidia.com/gpu\ndevices: []\n' >"${arg#--output=}"; fi
done
SH
  chmod +x "$test_root/bin/nvidia-ctk"
}
# Import the actual function, substituting only the hardware/install boundary.
# shellcheck disable=SC1090
source <(sed -n '/^setup_gpu()/,/^read_env()/ { /^read_env()/!p; }' "$script")
umask 077
setup_gpu
[[ "$(stat -c '%a' "$key")" == 644 ]]
printf 'PASS: NVIDIA key is readable by _apt and official repository signature verifies\n'
