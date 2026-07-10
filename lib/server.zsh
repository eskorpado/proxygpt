# Remote server configuration helpers.

typeset -gr PROXYGPT_REMOTE_PORT_CONFLICT_EXIT=42
typeset -gr PROXYGPT_TUNNEL_USER_CONFLICT_EXIT=43
typeset -gr PROXYGPT_SSHD_DROPIN_MARKER="# Managed by ProxyGPT. Manual changes may be replaced by the installer."

proxygpt_classify_remote_listener() {
  local details="${1-}"
  local line
  local saw_listener=0

  if [[ -z "$details" ]]; then
    print -r -- "free"
    return 0
  fi

  for line in "${(@f)details}"; do
    [[ -n "$line" ]] || continue
    saw_listener=1

    if [[ "$line" != *'"squid"'* ]]; then
      print -r -- "conflict"
      return 0
    fi
  done

  if (( saw_listener )); then
    print -r -- "squid"
  else
    print -r -- "free"
  fi
}

proxygpt_existing_tunnel_user_is_compatible() {
  local supplementary_groups="${1-}"
  local login_shell="${2-}"
  local password_state="${3-}"
  local group
  local has_tunnel_group=0

  for group in ${=supplementary_groups}; do
    if [[ "$group" == "codex-tunnel" ]]; then
      has_tunnel_group=1
      break
    fi
  done

  (( has_tunnel_group )) || return 1
  [[ "$login_shell" == "/usr/sbin/nologin" ]] || return 1
  [[ "$password_state" == "L" ]]
}

proxygpt_classify_sshd_dropin() {
  local dropin_path="${1:?sshd drop-in path is required}"
  local first_line

  if [[ ! -e "$dropin_path" && ! -L "$dropin_path" ]]; then
    print -r -- "missing"
    return 0
  fi

  if [[ ! -f "$dropin_path" ]]; then
    print -r -- "foreign"
    return 0
  fi

  IFS= read -r first_line < "$dropin_path" || first_line=""
  if [[ "$first_line" == "$PROXYGPT_SSHD_DROPIN_MARKER" ]]; then
    print -r -- "managed"
  else
    print -r -- "foreign"
  fi
}

proxygpt_sshd_config_text_includes_dropins() {
  local config_text="${1-}"
  local line
  local keyword
  local include_pattern
  local -a fields
  local in_global=1

  for line in "${(@f)config_text}"; do
    line="${line%%#*}"
    fields=("${(z)line}")
    (( ${#fields} > 0 )) || continue
    keyword="${fields[1]:l}"

    if [[ "$keyword" == "match" ]]; then
      if (( ${#fields} == 2 )) && [[ "${fields[2]:l}" == "all" ]]; then
        in_global=1
      else
        in_global=0
      fi
      continue
    fi

    (( in_global )) || continue
    [[ "$keyword" == "include" ]] || continue

    for include_pattern in "${fields[@]:1}"; do
      if [[ "$include_pattern" == "/etc/ssh/sshd_config.d/*.conf" || \
            "$include_pattern" == "sshd_config.d/*.conf" ]]; then
        return 0
      fi
    done
  done

  return 1
}

proxygpt_sshd_main_includes_dropins() {
  local main_config="${1:-/etc/ssh/sshd_config}"
  local config_text

  if [[ ! -r "$main_config" ]]; then
    proxygpt_die "Cannot read the main sshd configuration: ${main_config}"
    return 1
  fi

  config_text="$(<"$main_config")"
  if ! proxygpt_sshd_config_text_includes_dropins "$config_text"; then
    proxygpt_die \
      "Global Include for /etc/ssh/sshd_config.d/*.conf is missing; configure it manually and rerun"
    return 1
  fi
}

proxygpt_authorized_keys_files_are_compatible() {
  local effective_value="${1-}"
  local key_path

  for key_path in ${=effective_value}; do
    if [[ "$key_path" == ".ssh/authorized_keys" ]]; then
      return 0
    fi
  done
  return 1
}

proxygpt_render_squid_config() {
  local remote_port="${1:?remote Squid port is required}"
  local template_path="${PROXYGPT_ROOT}/templates/squid.conf"
  local rendered

  if [[ "$remote_port" != <-> ]] || (( remote_port < 1 || remote_port > 65535 )); then
    proxygpt_die "Invalid remote Squid port: ${remote_port}"
    return 1
  fi

  if [[ ! -f "$template_path" ]]; then
    proxygpt_die "Squid configuration template is missing: ${template_path}"
    return 1
  fi

  rendered="$(<"$template_path")"
  rendered="${rendered//\{\{REMOTE_PROXY_PORT\}\}/$remote_port}"

  if [[ "$rendered" == *'{{'* || "$rendered" == *'}}'* ]]; then
    proxygpt_die "Squid configuration contains an unresolved template value"
    return 1
  fi

  print -r -- "$rendered"
}

proxygpt_render_sshd_dropin() {
  local remote_port="${1:?remote Squid port is required}"
  local template_path="${PROXYGPT_ROOT}/templates/sshd-proxygpt.conf"
  local rendered

  if [[ "$remote_port" != <-> ]] || (( remote_port < 1 || remote_port > 65535 )); then
    proxygpt_die "Invalid remote Squid port: ${remote_port}"
    return 1
  fi

  if [[ ! -f "$template_path" ]]; then
    proxygpt_die "sshd policy template is missing: ${template_path}"
    return 1
  fi

  rendered="$(<"$template_path")"
  rendered="${rendered//\{\{REMOTE_PROXY_PORT\}\}/$remote_port}"

  if [[ "$rendered" == *'{{'* || "$rendered" == *'}}'* ]]; then
    proxygpt_die "sshd policy contains an unresolved template value"
    return 1
  fi

  print -r -- "$rendered"
}

proxygpt_prepare_server_package() {
  local package_dir
  local remote_port="$(proxygpt_config_get remote_proxy_port)"

  package_dir="$(mktemp -d /tmp/proxygpt-server-package.XXXXXXXX)" || return 1
  [[ "$package_dir" =~ '^/tmp/proxygpt-server-package\.[A-Za-z0-9]+$' ]] || return 1

  if ! proxygpt_render_squid_config "$remote_port" > "${package_dir}/squid.conf" ||
     ! proxygpt_render_sshd_dropin "$remote_port" > "${package_dir}/90-proxygpt-tunnel.conf" ||
     ! cp "${PROXYGPT_ROOT}/templates/sshd-authorized-keys-global.conf" "$package_dir/" ||
     ! cp "${PROXYGPT_ROOT}/templates/remote/server-common.sh" "$package_dir/" ||
     ! cp "${PROXYGPT_ROOT}/templates/remote/configure-server.sh" "$package_dir/"; then
    proxygpt_die "Could not assemble the local server package: ${package_dir}"
    return 1
  fi

  {
    proxygpt_shell_assignment TUNNEL_USER "$(proxygpt_config_get tunnel_user)"
    proxygpt_shell_assignment REMOTE_PORT "$remote_port"
    proxygpt_shell_assignment SERVER_HOST "$(proxygpt_config_get server_host)"
  } > "${package_dir}/settings.sh" || {
    proxygpt_die "Could not write server package settings: ${package_dir}"
    return 1
  }

  if ! chmod 600 "${package_dir}"/* ||
     ! chmod 700 "${package_dir}/configure-server.sh" ||
     ! bash -n "${package_dir}/configure-server.sh" "${package_dir}/server-common.sh" "${package_dir}/settings.sh"; then
    proxygpt_die "Server package validation failed: ${package_dir}"
    return 1
  fi

  proxygpt_config_set local_server_package_dir "$package_dir" || return 1
}

proxygpt_remove_local_server_package() {
  local package_dir="$(proxygpt_config_get local_server_package_dir)"
  [[ "$package_dir" =~ '^/tmp/proxygpt-server-package\.[A-Za-z0-9]+$' ]] || return 1
  if ! rm -rf "$package_dir"; then
    proxygpt_die "Could not remove the local server package: ${package_dir}"
    return 1
  fi
  proxygpt_config_set local_server_package_dir "" || return 1
}
