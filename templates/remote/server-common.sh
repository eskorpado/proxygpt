#!/usr/bin/env bash

proxygpt_reload_sshd() {
  local service_name
  local found_service=0

  for service_name in ssh sshd; do
    if ! systemctl cat "${service_name}.service" >/dev/null 2>&1; then
      continue
    fi

    found_service=1
    if systemctl reload "${service_name}.service"; then
      printf 'Reloaded %s.service\n' "$service_name"
      return 0
    fi
  done

  if (( ! found_service )); then
    printf 'Neither ssh.service nor sshd.service was found\n' >&2
  else
    printf 'sshd reload failed; restart fallback is disabled\n' >&2
  fi
  return 1
}

proxygpt_fix_tunnel_key_permissions() {
  local tunnel_user="${1:?tunnel user is required}"
  local tunnel_home="${2:?tunnel home is required}"
  local primary_group="${3:?primary group is required}"
  local ssh_dir="${tunnel_home}/.ssh"
  local authorized_keys="${ssh_dir}/authorized_keys"

  if [[ ! -d "$tunnel_home" || -L "$tunnel_home" ]]; then
    printf 'Tunnel home is not a real directory: %s\n' "$tunnel_home" >&2
    return 1
  fi

  if [[ -e "$ssh_dir" || -L "$ssh_dir" ]]; then
    if [[ ! -d "$ssh_dir" || -L "$ssh_dir" ]]; then
      printf 'Refusing unusual .ssh object: %s\n' "$ssh_dir" >&2
      return 1
    fi
  fi

  if [[ -e "$authorized_keys" || -L "$authorized_keys" ]]; then
    if [[ ! -f "$authorized_keys" || -L "$authorized_keys" ]]; then
      printf 'Refusing unusual authorized_keys object: %s\n' "$authorized_keys" >&2
      return 1
    fi
  fi

  chown "${tunnel_user}:${primary_group}" "$tunnel_home"

  if [[ ! -d "$ssh_dir" ]]; then
    install -d -m 0700 -o "$tunnel_user" -g "$primary_group" "$ssh_dir"
  else
    chown "${tunnel_user}:${primary_group}" "$ssh_dir"
    chmod 0700 "$ssh_dir"
  fi

  if [[ ! -e "$authorized_keys" ]]; then
    touch "$authorized_keys"
  fi
  chown "${tunnel_user}:${primary_group}" "$authorized_keys"
  chmod 0600 "$authorized_keys"
}

proxygpt_install_raw_authorized_key() {
  local tunnel_user="${1:?tunnel user is required}"
  local tunnel_home="${2:?tunnel home is required}"
  local primary_group="${3:?primary group is required}"
  local public_key_file="${4:?public key file is required}"
  local authorized_keys="${tunnel_home}/.ssh/authorized_keys"
  local staged_keys="${tunnel_home}/.ssh/.authorized_keys.proxygpt.$$"
  local raw_key
  local wanted_fingerprint
  local line
  local key_material
  local line_fingerprint

  proxygpt_fix_tunnel_key_permissions "$tunnel_user" "$tunnel_home" "$primary_group"

  IFS= read -r raw_key < "$public_key_file"
  [[ "$raw_key" == ssh-ed25519\ * ]] || {
    printf 'Staged public key is not raw Ed25519 material\n' >&2
    return 1
  }
  wanted_fingerprint="$(ssh-keygen -lf "$public_key_file" | awk '{print $2}')"
  [[ -n "$wanted_fingerprint" ]] || return 1

  : > "$staged_keys"
  chmod 0600 "$staged_keys"

  while IFS= read -r line || [[ -n "$line" ]]; do
    key_material=""
    line_fingerprint=""
    if [[ "$line" =~ (ssh-ed25519[[:space:]]+[^[:space:]]+) ]]; then
      key_material="${BASH_REMATCH[1]}"
      line_fingerprint="$(printf '%s\n' "$key_material" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')" || true
    fi

    if [[ -n "$line_fingerprint" && "$line_fingerprint" == "$wanted_fingerprint" ]]; then
      continue
    fi
    printf '%s\n' "$line" >> "$staged_keys"
  done < "$authorized_keys"

  printf '%s\n' "$raw_key" >> "$staged_keys"
  chown "${tunnel_user}:${primary_group}" "$staged_keys"
  chmod 0600 "$staged_keys"
  mv -f "$staged_keys" "$authorized_keys"
}

proxygpt_authorized_keys_files_are_compatible() {
  local effective_value="${1-}"
  local key_path

  for key_path in $effective_value; do
    [[ "$key_path" == ".ssh/authorized_keys" ]] && return 0
  done
  return 1
}

proxygpt_existing_tunnel_user_is_compatible() {
  local supplementary_groups="${1-}"
  local login_shell="${2-}"
  local password_state="${3-}"
  local group

  for group in $supplementary_groups; do
    if [[ "$group" == "codex-tunnel" && \
          "$login_shell" == "/usr/sbin/nologin" && \
          "$password_state" == "L" ]]; then
      return 0
    fi
  done
  return 1
}

proxygpt_sshd_main_includes_dropins() {
  local main_config="${1:-/etc/ssh/sshd_config}"

  awk '
    BEGIN { global = 1; found = 0 }
    {
      sub(/#.*/, "")
      if (tolower($1) == "match") {
        global = (NF == 2 && tolower($2) == "all")
        next
      }
      if (global && tolower($1) == "include") {
        for (i = 2; i <= NF; i++) {
          if ($i == "/etc/ssh/sshd_config.d/*.conf" || $i == "sshd_config.d/*.conf") found = 1
        }
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$main_config"
}
