# Phase 3: create and install the dedicated SSH identity.

proxygpt_step_identity() {
  local package_dir
  local remote_status=0
  local cleanup_status=0

  proxygpt_prepare_ssh_key || return 1
  proxygpt_prepare_identity_package || return 1
  package_dir="$(proxygpt_config_get local_identity_package_dir)" || return 1

  if proxygpt_remote_create_stage >/dev/null; then
    if proxygpt_remote_upload_files "${package_dir}"/*; then
      if proxygpt_remote_execute_staged_script install-identity.sh; then
        :
      else
        remote_status=$?
      fi
    else
      remote_status=$?
    fi
  else
    remote_status=$?
  fi

  if (( remote_status != 0 )); then
    return "$remote_status"
  fi

  proxygpt_remove_local_identity_package || cleanup_status=$?
  proxygpt_admin_master_stop || cleanup_status=$?

  if (( cleanup_status != 0 )); then
    return "$cleanup_status"
  fi

  proxygpt_success "Identity phase completed"
}
