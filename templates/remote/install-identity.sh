#!/usr/bin/env bash

set -euo pipefail
umask 077

readonly STAGE_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly SETTINGS_FILE="${STAGE_DIR}/settings.sh"
readonly COMMON_FILE="${STAGE_DIR}/server-common.sh"
readonly PUBLIC_KEY_FILE="${STAGE_DIR}/tunnel-key.pub"

[[ "$EUID" -eq 0 ]] || { printf 'Identity script must run as root\n' >&2; exit 1; }
[[ -r "$SETTINGS_FILE" && -r "$COMMON_FILE" && -r "$PUBLIC_KEY_FILE" ]] || {
  printf 'Incomplete identity package\n' >&2
  exit 1
}
source "$SETTINGS_FILE"
source "$COMMON_FILE"

: "${TUNNEL_USER:?}"
: "${SERVER_HOST:?}"
[[ "$TUNNEL_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || exit 1

groups="$(id -nG "$TUNNEL_USER")"
shell="$(getent passwd "$TUNNEL_USER" | cut -d: -f7)"
password_state="$(passwd -S "$TUNNEL_USER" | awk '{print $2}')"
if ! proxygpt_existing_tunnel_user_is_compatible "$groups" "$shell" "$password_state"; then
  printf 'Tunnel user changed after server configuration: %s\n' "$TUNNEL_USER" >&2
  exit 1
fi

tunnel_home="$(getent passwd "$TUNNEL_USER" | cut -d: -f6)"
primary_group="$(id -gn "$TUNNEL_USER")"
proxygpt_install_raw_authorized_key \
  "$TUNNEL_USER" \
  "$tunnel_home" \
  "$primary_group" \
  "$PUBLIC_KEY_FILE"

effective="$(sshd -T -C "user=${TUNNEL_USER},host=${SERVER_HOST},addr=127.0.0.1")"
authorized_files="$(awk '$1=="authorizedkeysfile" {$1=""; sub(/^ /, ""); print; exit}' <<< "$effective")"
proxygpt_authorized_keys_files_are_compatible "$authorized_files" || {
  printf 'Effective AuthorizedKeysFile no longer accepts .ssh/authorized_keys\n' >&2
  exit 1
}

fingerprint="$(ssh-keygen -lf "$PUBLIC_KEY_FILE" | awk '{print $2}')"
printf 'Installed raw tunnel public key (%s)\n' "$fingerprint"
