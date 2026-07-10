# TCP port validation and installer-time local conflict handling.

proxygpt_port_is_valid() {
  local port="${1-}"
  [[ "$port" == <-> ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

proxygpt_local_port_listener_details() {
  local port="${1:?local port is required}"

  proxygpt_port_is_valid "$port" || return 1
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null
}

proxygpt_local_port_is_in_use() {
  local port="${1:?local port is required}"
  local details

  if ! details="$(proxygpt_local_port_listener_details "$port")"; then
    return 1
  fi
  [[ -n "$details" ]]
}

proxygpt_prompt_local_proxy_port() {
  local default_port="$(proxygpt_config_get local_proxy_port)"
  local selected_port
  local details

  while true; do
    proxygpt_prompt_nonempty "Local proxy port" "$default_port"
    selected_port="$PROXYGPT_REPLY"

    if ! proxygpt_port_is_valid "$selected_port"; then
      proxygpt_warn "Port must be an integer from 1 to 65535"
      continue
    fi

    if proxygpt_local_port_is_in_use "$selected_port"; then
      proxygpt_warn "Local port ${selected_port} is already in use"
      details="$(proxygpt_local_port_listener_details "$selected_port")"
      print -ru2 -- "$details"
      default_port="$selected_port"
      continue
    fi

    proxygpt_config_set local_proxy_port "$selected_port"
    proxygpt_config_set tunnel_control_socket \
      "$(proxygpt_config_get tunnel_control_dir)/proxygpt-${selected_port}.sock"
    proxygpt_success "Local proxy port is available: ${selected_port}"
    return 0
  done
}
