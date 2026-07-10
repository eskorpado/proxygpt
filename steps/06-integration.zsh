# Phase 6: install the proxygpt command, verify, and print launch instructions.

proxygpt_step_integration() {
  local runtime_command="$(proxygpt_config_get runtime_command)"
  local tunnel_command="${runtime_command:h}/proxygpt-tunnel"
  local app_path="$(proxygpt_config_get app_path)"
  local cli_link="$(proxygpt_config_get cli_link_path)"
  local verification_status=0
  local cleanup_status=0

  proxygpt_install_cli_link || return 1

  if "$tunnel_command" start; then
    if proxygpt_test_local_proxy_listener &&
       proxygpt_test_required_proxy_endpoints; then
      :
    else
      verification_status=$?
    fi
  else
    verification_status=$?
  fi

  if "$tunnel_command" stop; then
    :
  else
    cleanup_status=$?
    proxygpt_warn "Could not stop the final verification tunnel"
  fi

  if (( verification_status != 0 )); then
    return "$verification_status"
  fi
  if (( cleanup_status != 0 )); then
    return "$cleanup_status"
  fi

  proxygpt_success "ProxyGPT installation completed"
  print
  print -r -- "Launch from Finder: ${app_path}"
  print -r -- "Launch from Terminal: ${cli_link}"
}
