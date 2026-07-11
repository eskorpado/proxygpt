# Central in-memory installer configuration.

typeset -ga PROXYGPT_CONFIG_KEYS=(
  profile_id
  product_name
  cli_name
  bundle_id
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

  PROXYGPT_CONFIG_KEY_SET=()
  for key in "${PROXYGPT_CONFIG_KEYS[@]}"; do
    PROXYGPT_CONFIG_KEY_SET[$key]=1
  done

  PROXYGPT_CONFIG=(
    profile_id ""
    product_name ""
    cli_name ""
    bundle_id ""
    server_host ""
    admin_user ""
    ssh_port "22"
    ssh_host_key_policy "accept-new"
    admin_control_dir ""
    admin_control_socket ""
    tunnel_user ""
    remote_proxy_port "3128"
    local_proxy_port ""
    tunnel_control_dir "${HOME}/.ssh/control"
    tunnel_control_socket ""
    ssh_key_path ""
    ssh_key_action ""
    data_root ""
    logs_dir ""
    installer_log ""
    runtime_command ""
    cli_link_path ""
    app_path ""
    target_app_name ""
    target_app_path ""
    target_app_executable ""
    remote_stage_dir ""
    local_server_package_dir ""
    local_identity_package_dir ""
    icon_mode "bundled"
    icon_source ""
  )
}

proxygpt_configure_profile() {
  local profile_id="${1:?profile id is required}"
  local local_user="${USER:-${LOGNAME:-}}"
  local product_name cli_name bundle_id tunnel_prefix data_root

  proxygpt_profile_is_valid "$profile_id" || {
    proxygpt_die "Unknown output profile: ${profile_id}"
    return 1
  }
  [[ -n "$local_user" ]] || local_user="$(id -un)"

  product_name="$(proxygpt_profile_field "$profile_id" product)"
  cli_name="$(proxygpt_profile_field "$profile_id" cli)"
  bundle_id="$(proxygpt_profile_field "$profile_id" bundle_id)"
  tunnel_prefix="$(proxygpt_profile_field "$profile_id" tunnel_prefix)"
  data_root="${HOME}/Library/Application Support/${product_name}"

  proxygpt_config_set profile_id "$profile_id"
  proxygpt_config_set product_name "$product_name"
  proxygpt_config_set cli_name "$cli_name"
  proxygpt_config_set bundle_id "$bundle_id"
  proxygpt_config_set tunnel_user "${tunnel_prefix}-${local_user}"
  proxygpt_config_set ssh_key_path "${HOME}/.ssh/${cli_name}_ed25519"
  proxygpt_config_set data_root "$data_root"
  proxygpt_config_set logs_dir "${data_root}/logs"
  proxygpt_config_set runtime_command "${data_root}/bin/${cli_name}"
  proxygpt_config_set cli_link_path "/usr/local/bin/${cli_name}"
  proxygpt_config_set app_path "${HOME}/Applications/${product_name}.app"
  proxygpt_config_set icon_source "${PROXYGPT_ROOT:-$PWD}/assets/${product_name}.icns"
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
