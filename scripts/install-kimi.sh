#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_URL="https://code.kimi.com/kimi-code/install.sh"
TMP_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/kimi-code-install.XXXXXX")"
trap 'rm -f "$TMP_SCRIPT"' EXIT

printf 'Downloading the official Kimi Code installer from:\n%s\n' "$INSTALL_URL"
curl --proto '=https' --tlsv1.2 -fsSL "$INSTALL_URL" -o "$TMP_SCRIPT"
sh "$TMP_SCRIPT"

printf '\nOpen a new shell, then verify with: kimi --version\n'
