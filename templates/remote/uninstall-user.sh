#!/usr/bin/env bash

set -euo pipefail

readonly TUNNEL_USER="${1:-}"
[[ "$EUID" -eq 0 ]] || { printf 'Uninstall script must run as root\n' >&2; exit 1; }
[[ "$TUNNEL_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
  printf 'Invalid tunnel username\n' >&2
  exit 1
}
[[ "$TUNNEL_USER" != root ]] || { printf 'Refusing to delete root\n' >&2; exit 1; }

if ! id "$TUNNEL_USER" >/dev/null 2>&1; then
  printf 'Tunnel account is already absent: %s\n' "$TUNNEL_USER"
  exit 0
fi

groups="$(id -nG "$TUNNEL_USER")"
shell="$(getent passwd "$TUNNEL_USER" | cut -d: -f7)"
password_state="$(passwd -S "$TUNNEL_USER" | awk '{print $2}')"
compatible=0
for group in $groups; do
  if [[ "$group" == codex-tunnel && "$shell" == /usr/sbin/nologin && "$password_state" == L ]]; then
    compatible=1
    break
  fi
done

if (( compatible == 0 )); then
  printf 'Tunnel account profile changed:\n  user: %s\n  groups: %s\n  shell: %s\n  password: %s\n' \
    "$TUNNEL_USER" "$groups" "$shell" "$password_state" >/dev/tty
  printf 'Delete this account and its home anyway?\n  1) Delete\n  2) Abort\nSelect: ' >/dev/tty
  IFS= read -r choice </dev/tty
  [[ "$choice" == 1 ]] || exit 1
fi

userdel --remove "$TUNNEL_USER"
printf 'Removed tunnel account and home: %s\n' "$TUNNEL_USER"
