# Phase 4: install, start, and verify the local tunnel manager.

proxygpt_step_tunnel() {
  local runtime_command="$(proxygpt_config_get runtime_command)"
  local tunnel_command="${runtime_command:h}/proxygpt-tunnel"
  local verification_status=0
  local cleanup_status=0

  proxygpt_install_runtime_files || return 1

  if "$tunnel_command" start; then
    if proxygpt_test_local_proxy_listener; then
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
    proxygpt_warn "Could not stop the phase-4 verification tunnel"
  fi

  if (( verification_status != 0 )); then
    return "$verification_status"
  fi
  if (( cleanup_status != 0 )); then
    return "$cleanup_status"
  fi

  proxygpt_success "Tunnel phase completed"
}
