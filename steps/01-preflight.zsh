# Phase 1: validate the local machine and collect installation inputs.

proxygpt_preflight_local() {
  local tool
  local -a required_tools=(
    awk
    cmp
    cp
    mv
    od
    rm
    ssh
    scp
    ssh-keygen
    plutil
    osascript
    ps
    lsof
    nc
    curl
    date
    killall
    mktemp
    rmdir
    sudo
    touch
    readlink
  )

  if [[ "$(uname -s)" != "Darwin" ]]; then
    proxygpt_die "ProxyGPT installer v1 requires macOS"
    return 1
  fi

  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      proxygpt_die "Required command is not available: ${tool}"
      return 1
    fi
  done

  if [[ ! -x /usr/libexec/PlistBuddy ]]; then
    proxygpt_die "Required command is not executable: /usr/libexec/PlistBuddy"
    return 1
  fi

  if [[ ! -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]]; then
    proxygpt_die "Required Launch Services registration tool is missing"
    return 1
  fi

  proxygpt_success "macOS and required local commands verified"
}

proxygpt_prompt_server_host() {
  while true; do
    proxygpt_prompt_nonempty "Server hostname or SSH alias"
    if [[ "$PROXYGPT_REPLY" =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]]; then
      proxygpt_config_set server_host "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Use a hostname or SSH alias without spaces, @, port, or options"
  done
}

proxygpt_prompt_admin_user() {
  while true; do
    proxygpt_prompt_nonempty "SSH admin username"
    if [[ "$PROXYGPT_REPLY" =~ '^[A-Za-z_][A-Za-z0-9._-]*$' ]]; then
      proxygpt_config_set admin_user "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Invalid SSH admin username"
  done
}

proxygpt_prompt_port_config() {
  local label="${1:?port label is required}"
  local key="${2:?config key is required}"
  local default_port="$(proxygpt_config_get "$key")"

  while true; do
    proxygpt_prompt_nonempty "$label" "$default_port"
    if proxygpt_port_is_valid "$PROXYGPT_REPLY"; then
      proxygpt_config_set "$key" "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Port must be an integer from 1 to 65535"
  done
}

proxygpt_prompt_tunnel_user() {
  local default_user="$(proxygpt_config_get tunnel_user)"

  while true; do
    proxygpt_prompt_nonempty "Tunnel username" "$default_user"
    if [[ "$PROXYGPT_REPLY" =~ '^[a-z_][a-z0-9_-]{0,31}$' ]]; then
      proxygpt_config_set tunnel_user "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Use 1-32 lowercase letters, digits, underscores, or hyphens"
  done
}

proxygpt_prompt_app_path() {
  local default_path="$(proxygpt_config_get app_path)"
  local product_name="$(proxygpt_config_get product_name)"
  local selected_path

  while true; do
    proxygpt_prompt_nonempty "${product_name} app location" "$default_path"
    selected_path="$(proxygpt_expand_user_path "$PROXYGPT_REPLY")"
    if proxygpt_app_path_is_safe "$selected_path" && \
       [[ "${selected_path:t}" == "${product_name}.app" ]]; then
      proxygpt_config_set app_path "$selected_path"
      return 0
    fi
    proxygpt_warn "App path must be absolute and end with ${product_name}.app"
    default_path=""
  done
}

proxygpt_print_install_summary() {
  print
  print -r -- "Installation summary"
  print -r -- "  Output profile:   $(proxygpt_config_get product_name)"
  print -r -- "  Target app:       $(proxygpt_config_get target_app_path)"
  print -r -- "  Server:           $(proxygpt_config_get admin_user)@$(proxygpt_config_get server_host):$(proxygpt_config_get ssh_port)"
  print -r -- "  Tunnel user:      $(proxygpt_config_get tunnel_user)"
  print -r -- "  Remote proxy:     127.0.0.1:$(proxygpt_config_get remote_proxy_port)"
  print -r -- "  Local proxy:      127.0.0.1:$(proxygpt_config_get local_proxy_port)"
  print -r -- "  SSH key:          $(proxygpt_config_get ssh_key_path) ($(proxygpt_config_get ssh_key_action))"
  print -r -- "  Output app:       $(proxygpt_config_get app_path)"
  print -r -- "  CLI command:      $(proxygpt_config_get cli_link_path)"
  print -r -- "  Icon:             $(proxygpt_config_get icon_source)"
}

proxygpt_step_preflight() {
  proxygpt_preflight_local
  proxygpt_prompt_target_app
  proxygpt_success "Target application: $(proxygpt_config_get target_app_path)"
  proxygpt_prompt_server_host
  proxygpt_prompt_admin_user
  proxygpt_prompt_port_config "SSH admin port" ssh_port
  proxygpt_prompt_tunnel_user
  proxygpt_prompt_port_config "Remote Squid port" remote_proxy_port
  proxygpt_prompt_local_proxy_port
  proxygpt_prompt_ssh_key_path
  proxygpt_prompt_app_path
  proxygpt_validate_bundled_icon

  proxygpt_print_install_summary
  proxygpt_prompt_yes_no "Proceed?" yes
  if [[ "$PROXYGPT_REPLY" != "yes" ]]; then
    proxygpt_warn "Installation cancelled before changes"
    return 130
  fi

  proxygpt_log_init
  proxygpt_write_install_manifest || return 1
  proxygpt_success "Installation confirmed"
}
