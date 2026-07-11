# Этап 2: удалённая настройка Squid и ограничивающей политики sshd.

proxygpt_step_server() {
  local exit_code
  local package_dir

  proxygpt_admin_master_start || return 1

  while true; do
    proxygpt_prepare_server_package || return 1
    package_dir="$(proxygpt_config_get local_server_package_dir)" || return 1
    proxygpt_remote_create_stage >/dev/null || return 1
    proxygpt_remote_upload_files "${package_dir}"/* || return 1

    if proxygpt_remote_execute_staged_script configure-server.sh; then
      exit_code=0
    else
      exit_code=$?
    fi

    case "$exit_code" in
      0)
        proxygpt_remove_local_server_package || return 1
        proxygpt_success "Серверный этап завершён"
        return 0
        ;;
      42)
        proxygpt_remote_remove_stage || return 1
        proxygpt_remove_local_server_package || return 1
        proxygpt_warn "Выберите другой удалённый порт Squid"
        proxygpt_prompt_port_config "Удалённый порт Squid" remote_proxy_port || return 1
        proxygpt_write_install_manifest || return 1
        ;;
      43)
        proxygpt_remote_remove_stage || return 1
        proxygpt_remove_local_server_package || return 1
        proxygpt_warn "Выберите другое имя пользователя туннеля"
        proxygpt_prompt_tunnel_user || return 1
        proxygpt_write_install_manifest || return 1
        ;;
      *)
        return "$exit_code"
        ;;
    esac
  done
}
