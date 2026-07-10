# Central in-memory installer configuration.

typeset -ga PROXYGPT_CONFIG_KEYS=(
  server_host
  admin_user
  ssh_port
  ssh_host_key_policy
  admin_control_dir
  admin_control_socket
  tunnel_user
  remote_proxy_port
  local_proxy_port
  tunnel_control_dir
  tunnel_control_socket
  ssh_key_path
  ssh_key_action
  data_root
  logs_dir
  installer_log
  runtime_command
  cli_link_path
  app_path
  target_app_name
  target_app_path
  target_app_executable
  remote_stage_dir
  local_server_package_dir
  local_identity_package_dir
  icon_mode
  icon_source
)

typeset -gA PROXYGPT_CONFIG=()
typeset -gA PROXYGPT_CONFIG_KEY_SET=()

proxygpt_config_init() {
  local key
  local local_user="${USER:-${LOGNAME:-}}"

  if [[ -z "$local_user" ]]; then
    local_user="$(id -un)"
  fi

  PROXYGPT_CONFIG_KEY_SET=()
  for key in "${PROXYGPT_CONFIG_KEYS[@]}"; do
    PROXYGPT_CONFIG_KEY_SET[$key]=1
  done

  PROXYGPT_CONFIG=(
    server_host ""
    admin_user ""
    ssh_port "22"
    ssh_host_key_policy "accept-new"
    admin_control_dir ""
    admin_control_socket ""
    tunnel_user "codex-${local_user}"
    remote_proxy_port "3128"
    local_proxy_port "3128"
    tunnel_control_dir "${HOME}/.ssh/control"
    tunnel_control_socket "${HOME}/.ssh/control/proxygpt-3128.sock"
    ssh_key_path "${HOME}/.ssh/proxygpt_ed25519"
    ssh_key_action ""
    data_root "${HOME}/Library/Application Support/ProxyGPT"
    logs_dir "${HOME}/Library/Application Support/ProxyGPT/logs"
    installer_log ""
    runtime_command "${HOME}/Library/Application Support/ProxyGPT/bin/proxygpt"
    cli_link_path "/usr/local/bin/proxygpt"
    app_path "${HOME}/Applications/ProxyGPT.app"
    target_app_name ""
    target_app_path ""
    target_app_executable ""
    remote_stage_dir ""
    local_server_package_dir ""
    local_identity_package_dir ""
    icon_mode "bundled"
    icon_source "${PROXYGPT_ROOT:-$PWD}/ProxyGPT.icns"
  )
}

proxygpt_config_has_key() {
  local key="${1:?configuration key is required}"
  [[ -n "${PROXYGPT_CONFIG_KEY_SET[$key]-}" ]]
}

proxygpt_config_get() {
  local key="${1:?configuration key is required}"

  if ! proxygpt_config_has_key "$key"; then
    proxygpt_die "Unknown configuration key: ${key}"
    return 1
  fi

  print -r -- "${PROXYGPT_CONFIG[$key]-}"
}

proxygpt_config_set() {
  local key="${1:?configuration key is required}"
  local value="${2-}"

  if ! proxygpt_config_has_key "$key"; then
    proxygpt_die "Unknown configuration key: ${key}"
    return 1
  fi

  PROXYGPT_CONFIG[$key]="$value"
}
