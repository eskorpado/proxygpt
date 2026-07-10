#!/usr/bin/env bash

set -euo pipefail
umask 077

readonly STAGE_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly SETTINGS_FILE="${STAGE_DIR}/settings.sh"
readonly COMMON_FILE="${STAGE_DIR}/server-common.sh"

[[ "$EUID" -eq 0 ]] || { printf 'Server script must run as root\n' >&2; exit 1; }
[[ -r "$SETTINGS_FILE" && -r "$COMMON_FILE" ]] || { printf 'Incomplete server package\n' >&2; exit 1; }
source "$SETTINGS_FILE"
source "$COMMON_FILE"

: "${TUNNEL_USER:?}"
: "${REMOTE_PORT:?}"
: "${SERVER_HOST:?}"
[[ "$TUNNEL_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || exit 1
[[ "$REMOTE_PORT" =~ ^[0-9]+$ ]] && (( REMOTE_PORT >= 1 && REMOTE_PORT <= 65535 )) || exit 1

readonly SQUID_INPUT="${STAGE_DIR}/squid.conf"
readonly SSHD_INPUT="${STAGE_DIR}/90-proxygpt-tunnel.conf"
readonly AUTH_KEYS_SNIPPET="${STAGE_DIR}/sshd-authorized-keys-global.conf"
readonly SSHD_MAIN="/etc/ssh/sshd_config"
readonly SSHD_DROPIN="/etc/ssh/sshd_config.d/90-proxygpt-tunnel.conf"
readonly TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
readonly SQUID_TEMP="/etc/squid/.squid.conf.proxygpt.$$.tmp"
readonly SSHD_DROPIN_TEMP="/etc/ssh/sshd_config.d/.90-proxygpt-tunnel.conf.proxygpt.$$.tmp"
readonly SSHD_TEST="/etc/ssh/.sshd_config.proxygpt.$$.test"
readonly SSHD_BODY_TEMP="/etc/ssh/.sshd_config.proxygpt.$$.body"
readonly SSHD_MAIN_TEMP="/etc/ssh/.sshd_config.proxygpt.$$.tmp"

cleanup_temporary_files() {
  rm -f -- "$SQUID_TEMP" "$SSHD_DROPIN_TEMP" "$SSHD_TEST" "$SSHD_BODY_TEMP" "$SSHD_MAIN_TEMP"
}
trap cleanup_temporary_files EXIT

prompt_replace() {
  local label="$1" choice
  printf '%s\n  1) Replace\n  2) Abort\nSelect: ' "$label" >/dev/tty
  IFS= read -r choice </dev/tty
  [[ "$choice" == 1 ]]
}

listener_details="$(ss -H -ltnp "sport = :${REMOTE_PORT}" || true)"
if [[ -n "$listener_details" ]]; then
  while IFS= read -r line; do
    [[ "$line" == *'"squid"'* ]] || {
      printf 'Remote port %s is owned by another or unknown process:\n%s\n' "$REMOTE_PORT" "$listener_details" >&2
      exit 42
    }
  done <<< "$listener_details"
fi

if id "$TUNNEL_USER" >/dev/null 2>&1; then
  groups="$(id -nG "$TUNNEL_USER")"
  shell="$(getent passwd "$TUNNEL_USER" | cut -d: -f7)"
  password_state="$(passwd -S "$TUNNEL_USER" | awk '{print $2}')"
  if ! proxygpt_existing_tunnel_user_is_compatible "$groups" "$shell" "$password_state"; then
    printf 'Existing tunnel username is incompatible: user=%s groups=%s shell=%s password=%s\n' \
      "$TUNNEL_USER" "$groups" "$shell" "$password_state" >&2
    exit 43
  fi
  user_preexisted=1
else
  user_preexisted=0
fi

source /etc/os-release
case "${ID:-}" in debian|ubuntu) ;; *) printf 'Unsupported server OS: %s\n' "${ID:-unknown}" >&2; exit 1;; esac
proxygpt_sshd_main_includes_dropins "$SSHD_MAIN" || {
  printf 'Global Include for /etc/ssh/sshd_config.d/*.conf is missing\n' >&2
  exit 1
}

if command -v squid >/dev/null 2>&1; then
  squid_preexisted=1
  prompt_replace 'Existing Squid installation detected.' || exit 1
else
  squid_preexisted=0
  apt-get update
  apt-get install -y squid
fi

getent group codex-tunnel >/dev/null || groupadd codex-tunnel
if (( user_preexisted == 0 )); then
  useradd --create-home --user-group --shell /usr/sbin/nologin "$TUNNEL_USER"
  usermod --append --groups codex-tunnel "$TUNNEL_USER"
  passwd --lock "$TUNNEL_USER"
fi

tunnel_home="$(getent passwd "$TUNNEL_USER" | cut -d: -f6)"
primary_group="$(id -gn "$TUNNEL_USER")"
proxygpt_fix_tunnel_key_permissions "$TUNNEL_USER" "$tunnel_home" "$primary_group"

install -m 0644 "$SQUID_INPUT" "$SQUID_TEMP"
squid -f "$SQUID_TEMP" -k parse
cp -a /etc/squid/squid.conf "/etc/squid/squid.conf.proxygpt-backup-${TIMESTAMP}"
mv -f "$SQUID_TEMP" /etc/squid/squid.conf
squid -f /etc/squid/squid.conf -k parse
systemctl enable squid.service
systemctl restart squid.service

final_listener="$(ss -H -ltnp "sport = :${REMOTE_PORT}" || true)"
[[ -n "$final_listener" ]] || { printf 'Squid listener is absent\n' >&2; exit 1; }
while IFS= read -r line; do
  [[ "$line" == *"127.0.0.1:${REMOTE_PORT}"* && "$line" == *'"squid"'* ]] || {
    printf 'Unsafe final Squid listener:\n%s\n' "$final_listener" >&2; exit 1;
  }
done <<< "$final_listener"

if getent group codex-tunnel >/dev/null; then
  members="$(getent group codex-tunnel | cut -d: -f4)"
  current_port="$(awk '/^[[:space:]]*PermitOpen[[:space:]]+127\.0\.0\.1:/ {sub(/.*:/, ""); print; exit}' "$SSHD_DROPIN" 2>/dev/null || true)"
  if [[ -n "$members" && -n "$current_port" && "$current_port" != "$REMOTE_PORT" ]]; then
    printf 'WARNING: updating shared PermitOpen for group members: %s\n' "$members" >&2
  fi
fi

if [[ -e "$SSHD_DROPIN" || -L "$SSHD_DROPIN" ]]; then
  first_line="$(head -n 1 "$SSHD_DROPIN" 2>/dev/null || true)"
  if [[ "$first_line" != '# Managed by ProxyGPT. Manual changes may be replaced by the installer.' ]]; then
    cp -a "$SSHD_DROPIN" "${SSHD_DROPIN}.proxygpt-backup-${TIMESTAMP}"
    prompt_replace "Foreign sshd drop-in detected at ${SSHD_DROPIN}." || exit 1
    rm -rf "$SSHD_DROPIN"
  fi
fi

install -m 0600 "$SSHD_INPUT" "$SSHD_DROPIN_TEMP"
{ printf 'Include %s\n' "$SSHD_DROPIN_TEMP"; cat "$SSHD_MAIN"; } > "$SSHD_TEST"
sshd -t -f "$SSHD_TEST"
rm -f "$SSHD_TEST"
[[ -e "$SSHD_DROPIN" ]] && cp -a "$SSHD_DROPIN" "${SSHD_DROPIN}.proxygpt-backup-${TIMESTAMP}"
mv -f "$SSHD_DROPIN_TEMP" "$SSHD_DROPIN"
sshd -t

effective="$(sshd -T -C "user=${TUNNEL_USER},host=${SERVER_HOST},addr=127.0.0.1")"
authorized_files="$(awk '$1=="authorizedkeysfile" {$1=""; sub(/^ /, ""); print; exit}' <<< "$effective")"
if ! proxygpt_authorized_keys_files_are_compatible "$authorized_files"; then
  prompt_replace 'Effective AuthorizedKeysFile lacks .ssh/authorized_keys. Apply global policy for all SSH users?' || exit 1
  awk '
    /# >>> ProxyGPT AuthorizedKeysFile >>>/ { skip=1; next }
    /# <<< ProxyGPT AuthorizedKeysFile <<</ { skip=0; next }
    !skip { print }
  ' "$SSHD_MAIN" > "$SSHD_BODY_TEMP"
  { cat "$AUTH_KEYS_SNIPPET"; cat "$SSHD_BODY_TEMP"; } > "$SSHD_MAIN_TEMP"
  rm -f "$SSHD_BODY_TEMP"
  sshd -t -f "$SSHD_MAIN_TEMP"
  cp -a "$SSHD_MAIN" "${SSHD_MAIN}.proxygpt-backup-${TIMESTAMP}"
  mv -f "$SSHD_MAIN_TEMP" "$SSHD_MAIN"
  sshd -t
fi

proxygpt_reload_sshd
effective="$(sshd -T -C "user=${TUNNEL_USER},host=${SERVER_HOST},addr=127.0.0.1")"
authorized_files="$(awk '$1=="authorizedkeysfile" {$1=""; sub(/^ /, ""); print; exit}' <<< "$effective")"
proxygpt_authorized_keys_files_are_compatible "$authorized_files" || exit 1
grep -Fxq 'pubkeyauthentication yes' <<< "$effective"
grep -Fxq 'strictmodes yes' <<< "$effective"
grep -Fxq 'allowtcpforwarding local' <<< "$effective"
grep -Fxq "permitopen 127.0.0.1:${REMOTE_PORT}" <<< "$effective"
grep -Fxq 'passwordauthentication no' <<< "$effective"
grep -Fxq 'kbdinteractiveauthentication no' <<< "$effective"
grep -Fxq 'permittty no' <<< "$effective"
grep -Fxq 'allowagentforwarding no' <<< "$effective"
grep -Fxq 'x11forwarding no' <<< "$effective"
grep -Fxq 'forcecommand none' <<< "$effective"

printf 'Server configuration completed\n'
