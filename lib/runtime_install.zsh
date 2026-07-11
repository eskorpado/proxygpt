# Persisted runtime config and executable installation.

proxygpt_shell_assignment() {
  local name="${1:?variable name is required}"
  local value="${2-}"

  [[ "$name" =~ '^[A-Z][A-Z0-9_]*$' ]] || return 1
  print -r -- "${name}=${(qqq)value}"
}

proxygpt_write_runtime_config() {
  local data_root="$(proxygpt_config_get data_root)"
  local config_dir="${data_root}/config"
  local config_file="${config_dir}/proxygpt.conf"
  local temp_file="${config_file}.tmp.$$"

  if ! mkdir -p "$config_dir" || ! chmod 700 "$data_root" "$config_dir"; then
    proxygpt_die "Could not prepare runtime configuration directory: ${config_dir}"
    return 1
  fi

  {
    proxygpt_shell_assignment SERVER "$(proxygpt_config_get server_host)"
    proxygpt_shell_assignment SERVER_USER "$(proxygpt_config_get tunnel_user)"
    proxygpt_shell_assignment SSH_PORT "$(proxygpt_config_get ssh_port)"
    proxygpt_shell_assignment SSH_KEY "$(proxygpt_config_get ssh_key_path)"
    proxygpt_shell_assignment SSH_HOST_KEY_POLICY "$(proxygpt_config_get ssh_host_key_policy)"
    proxygpt_shell_assignment LOCAL_PORT "$(proxygpt_config_get local_proxy_port)"
    proxygpt_shell_assignment REMOTE_PORT "$(proxygpt_config_get remote_proxy_port)"
    proxygpt_shell_assignment CONTROL_DIR "$(proxygpt_config_get tunnel_control_dir)"
    proxygpt_shell_assignment CONTROL_SOCKET "$(proxygpt_config_get tunnel_control_socket)"
    proxygpt_shell_assignment TARGET_APP_NAME "$(proxygpt_config_get target_app_name)"
    proxygpt_shell_assignment TARGET_APP_EXECUTABLE "$(proxygpt_config_get target_app_executable)"
    proxygpt_shell_assignment PRODUCT_NAME "$(proxygpt_config_get product_name)"
  } > "$temp_file" || {
    proxygpt_die "Could not write runtime configuration: ${temp_file}"
    return 1
  }

  if ! chmod 600 "$temp_file" ||
     ! zsh -n "$temp_file" ||
     ! mv -f "$temp_file" "$config_file"; then
    proxygpt_die "Runtime configuration validation or installation failed: ${config_file}"
    return 1
  fi
  proxygpt_success "Runtime configuration installed: ${config_file}"
}

proxygpt_write_install_manifest() {
  local data_root="$(proxygpt_config_get data_root)"
  local config_dir="${data_root}/config"
  local manifest="${config_dir}/install-manifest.conf"
  local temp_file="${manifest}.tmp.$$"

  if ! mkdir -p "$config_dir" || ! chmod 700 "$data_root" "$config_dir"; then
    proxygpt_die "Could not prepare installation manifest directory: ${config_dir}"
    return 1
  fi

  {
    proxygpt_shell_assignment MANIFEST_SCHEMA "2"
    proxygpt_shell_assignment PROFILE_ID "$(proxygpt_config_get profile_id)"
    proxygpt_shell_assignment PRODUCT_NAME "$(proxygpt_config_get product_name)"
    proxygpt_shell_assignment CLI_NAME "$(proxygpt_config_get cli_name)"
    proxygpt_shell_assignment BUNDLE_ID "$(proxygpt_config_get bundle_id)"
    proxygpt_shell_assignment SERVER "$(proxygpt_config_get server_host)"
    proxygpt_shell_assignment ADMIN_USER "$(proxygpt_config_get admin_user)"
    proxygpt_shell_assignment SSH_PORT "$(proxygpt_config_get ssh_port)"
    proxygpt_shell_assignment SSH_HOST_KEY_POLICY "$(proxygpt_config_get ssh_host_key_policy)"
    proxygpt_shell_assignment TUNNEL_USER "$(proxygpt_config_get tunnel_user)"
    proxygpt_shell_assignment SSH_KEY "$(proxygpt_config_get ssh_key_path)"
    proxygpt_shell_assignment LOCAL_PORT "$(proxygpt_config_get local_proxy_port)"
    proxygpt_shell_assignment CONTROL_DIR "$(proxygpt_config_get tunnel_control_dir)"
    proxygpt_shell_assignment CONTROL_SOCKET "$(proxygpt_config_get tunnel_control_socket)"
    proxygpt_shell_assignment DATA_ROOT "$data_root"
    proxygpt_shell_assignment RUNTIME_COMMAND "$(proxygpt_config_get runtime_command)"
    proxygpt_shell_assignment CLI_LINK "$(proxygpt_config_get cli_link_path)"
    proxygpt_shell_assignment APP_PATH "$(proxygpt_config_get app_path)"
  } > "$temp_file" || {
    proxygpt_die "Could not write installation manifest: ${temp_file}"
    return 1
  }

  if ! chmod 600 "$temp_file" ||
     ! zsh -n "$temp_file" ||
     ! mv -f "$temp_file" "$manifest"; then
    proxygpt_die "Installation manifest validation or installation failed: ${manifest}"
    return 1
  fi

  proxygpt_success "Installation manifest installed: ${manifest}"
}

proxygpt_install_runtime_files() {
  local data_root="$(proxygpt_config_get data_root)"
  local bin_dir="${data_root}/bin"
  local runtime_command="$(proxygpt_config_get runtime_command)"
  local tunnel_command="${bin_dir}/proxygpt-tunnel"
  local runtime_temp="${runtime_command}.tmp.$$"
  local tunnel_temp="${tunnel_command}.tmp.$$"

  if ! mkdir -p "$bin_dir" || ! chmod 700 "$data_root" "$bin_dir"; then
    proxygpt_die "Could not prepare runtime executable directory: ${bin_dir}"
    return 1
  fi

  if ! cp "${PROXYGPT_ROOT}/templates/runtime/proxygpt" "$runtime_temp" ||
     ! cp "${PROXYGPT_ROOT}/templates/runtime/proxygpt-tunnel" "$tunnel_temp" ||
     ! chmod 755 "$runtime_temp" "$tunnel_temp" ||
     ! zsh -n -o NO_BG_NICE "$runtime_temp" ||
     ! zsh -n "$tunnel_temp" ||
     ! mv -f "$runtime_temp" "$runtime_command" ||
     ! mv -f "$tunnel_temp" "$tunnel_command"; then
    proxygpt_die "Runtime script validation or installation failed"
    return 1
  fi

  proxygpt_write_runtime_config || return 1
  proxygpt_write_install_manifest || return 1
  proxygpt_success "$(proxygpt_config_get product_name) runtime scripts installed"
}
