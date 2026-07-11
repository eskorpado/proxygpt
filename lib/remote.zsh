# Транспорт SSH/scp для одного подготовленного привилегированного серверного скрипта.

proxygpt_remote_admin_target() {
  local admin_user="$(proxygpt_config_get admin_user)"
  local server_host="$(proxygpt_config_get server_host)"

  if [[ ! "$admin_user" =~ '^[A-Za-z_][A-Za-z0-9._-]*$' ]]; then
    proxygpt_die "Недопустимое имя администратора SSH: ${admin_user}"
    return 1
  fi

  if [[ ! "$server_host" =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]]; then
    proxygpt_die "Недопустимое имя сервера или SSH-алиас: ${server_host}"
    return 1
  fi

  print -r -- "${admin_user}@${server_host}"
}

proxygpt_remote_validate_stage_dir() {
  local remote_stage="${1-}"
  [[ -n "$remote_stage" ]] || return 1
  [[ "$remote_stage" =~ '^/tmp/proxygpt\.[A-Za-z0-9]+$' ]]
}

proxygpt_admin_validate_control_dir() {
  local control_dir="${1-}"
  [[ -n "$control_dir" ]] || return 1
  [[ "$control_dir" =~ '^/tmp/proxygpt-admin\.[A-Za-z0-9]+$' ]]
}

proxygpt_admin_validate_control_socket() {
  local control_socket="${1-}"
  [[ -n "$control_socket" ]] || return 1
  [[ "$control_socket" =~ '^/tmp/proxygpt-admin\.[A-Za-z0-9]+/master\.sock$' ]]
}

proxygpt_admin_master_check() {
  local control_socket="$(proxygpt_config_get admin_control_socket)"
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"

  proxygpt_admin_validate_control_socket "$control_socket" || return 1

  ssh \
    -S "$control_socket" \
    -O check \
    -p "$ssh_port" \
    "$target" \
    >/dev/null 2>&1
}

proxygpt_admin_master_start() {
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"
  local host_key_policy="$(proxygpt_config_get ssh_host_key_policy)"
  local control_dir
  local control_socket

  if proxygpt_admin_master_check; then
    proxygpt_success "Административный SSH master уже запущен"
    return 0
  fi

  control_dir="$(mktemp -d /tmp/proxygpt-admin.XXXXXXXX)"
  chmod 700 "$control_dir"
  control_socket="${control_dir}/master.sock"

  if ! proxygpt_admin_validate_control_dir "$control_dir" || \
     ! proxygpt_admin_validate_control_socket "$control_socket"; then
    proxygpt_die "Неожиданный путь административного управляющего сокета: ${control_socket}"
    return 1
  fi

  proxygpt_config_set admin_control_dir "$control_dir"
  proxygpt_config_set admin_control_socket "$control_socket"

  if ! ssh \
    -M \
    -S "$control_socket" \
    -f \
    -N \
    -o "StrictHostKeyChecking=${host_key_policy}" \
    -o ControlPersist=300 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -p "$ssh_port" \
    "$target"; then
    proxygpt_die "Не удалось запустить административное SSH master-соединение; управляющий каталог: ${control_dir}"
    return 1
  fi

  if ! proxygpt_admin_master_check; then
    proxygpt_die "Административный SSH master не прошёл проверку: ${control_socket}"
    return 1
  fi

  proxygpt_success "Административный SSH master запущен"
}

proxygpt_admin_master_require() {
  if ! proxygpt_admin_master_check; then
    proxygpt_die "Административный SSH master недоступен"
    return 1
  fi
}

proxygpt_admin_master_stop() {
  local control_dir="$(proxygpt_config_get admin_control_dir)"
  local control_socket="$(proxygpt_config_get admin_control_socket)"
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"

  if [[ -z "$control_dir" && -z "$control_socket" ]]; then
    return 0
  fi

  if ! proxygpt_admin_validate_control_dir "$control_dir" || \
     ! proxygpt_admin_validate_control_socket "$control_socket"; then
    proxygpt_die "Отказ от очистки неожиданного административного управляющего пути"
    return 1
  fi

  if proxygpt_admin_master_check; then
    if ! ssh \
      -S "$control_socket" \
      -O exit \
      -p "$ssh_port" \
      "$target" \
      >/dev/null; then
      proxygpt_die "Не удалось остановить административный SSH master: ${control_socket}"
      return 1
    fi
  elif [[ -S "$control_socket" ]]; then
    proxygpt_die "Административный управляющий сокет неисправен и сохранён: ${control_socket}"
    return 1
  fi

  if [[ -d "$control_dir" ]]; then
    if ! rmdir "$control_dir"; then
      proxygpt_warn "Административный управляющий каталог не пуст и сохранён: ${control_dir}"
    fi
  fi

  proxygpt_config_set admin_control_dir ""
  proxygpt_config_set admin_control_socket ""
  proxygpt_success "Административный SSH master остановлен"
}

proxygpt_remote_create_stage() {
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"
  local host_key_policy="$(proxygpt_config_get ssh_host_key_policy)"
  local control_socket="$(proxygpt_config_get admin_control_socket)"
  local remote_stage

  proxygpt_admin_master_require

  if [[ "$ssh_port" != <-> ]] || (( ssh_port < 1 || ssh_port > 65535 )); then
    proxygpt_die "Недопустимый порт SSH: ${ssh_port}"
    return 1
  fi

  if ! remote_stage="$(ssh \
    -S "$control_socket" \
    -o ControlMaster=auto \
    -o "StrictHostKeyChecking=${host_key_policy}" \
    -p "$ssh_port" \
    "$target" \
    'umask 077; mktemp -d /tmp/proxygpt.XXXXXXXX')"; then
    proxygpt_die "Не удалось создать защищённый удалённый временный каталог"
    return 1
  fi

  remote_stage="${remote_stage//$'\r'/}"
  if ! proxygpt_remote_validate_stage_dir "$remote_stage"; then
    proxygpt_die "Сервер вернул неожиданный путь временного каталога: ${remote_stage}"
    return 1
  fi

  proxygpt_config_set remote_stage_dir "$remote_stage"
  proxygpt_log INFO "Создан удалённый временный каталог"
  print -r -- "$remote_stage"
}

proxygpt_remote_upload_files() {
  local remote_stage="$(proxygpt_config_get remote_stage_dir)"
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"
  local host_key_policy="$(proxygpt_config_get ssh_host_key_policy)"
  local control_socket="$(proxygpt_config_get admin_control_socket)"
  local local_path

  proxygpt_admin_master_require

  if ! proxygpt_remote_validate_stage_dir "$remote_stage"; then
    proxygpt_die "Удалённый временный каталог не инициализирован"
    return 1
  fi

  if (( $# == 0 )); then
    proxygpt_die "Не указаны файлы для удалённой загрузки"
    return 1
  fi

  for local_path in "$@"; do
    if [[ ! -f "$local_path" ]]; then
      proxygpt_die "Источник удалённой загрузки не является файлом: ${local_path}"
      return 1
    fi
  done

  scp \
    -o "ControlPath=${control_socket}" \
    -o ControlMaster=auto \
    -o "StrictHostKeyChecking=${host_key_policy}" \
    -P "$ssh_port" \
    -- \
    "$@" \
    "${target}:${remote_stage}/"
  proxygpt_log INFO "Во временный удалённый каталог загружено файлов: ${#}"
}

proxygpt_remote_remove_stage() {
  local remote_stage="$(proxygpt_config_get remote_stage_dir)"
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"
  local control_socket="$(proxygpt_config_get admin_control_socket)"

  if [[ -z "$remote_stage" ]]; then
    return 0
  fi
  if ! proxygpt_remote_validate_stage_dir "$remote_stage"; then
    proxygpt_die "Отказ от удаления неожиданного удалённого временного пути"
    return 1
  fi
  proxygpt_admin_master_require || return 1

  if ! ssh \
    -S "$control_socket" \
    -o ControlMaster=auto \
    -p "$ssh_port" \
    "$target" \
    "rm -rf -- '${remote_stage}'"; then
    proxygpt_die "Не удалось удалить удалённый временный каталог: ${remote_stage}"
    return 1
  fi

  proxygpt_config_set remote_stage_dir "" || return 1
  proxygpt_log INFO "Удалён удалённый временный каталог"
}

proxygpt_remote_script_command() {
  local script_name="${1:?требуется имя удалённого скрипта}"
  local remote_stage="$(proxygpt_config_get remote_stage_dir)"
  local admin_user="$(proxygpt_config_get admin_user)"
  local runner
  local remote_script

  if ! proxygpt_remote_validate_stage_dir "$remote_stage"; then
    proxygpt_die "Удалённый временный каталог не инициализирован"
    return 1
  fi

  if [[ ! "$script_name" =~ '^[A-Za-z0-9._-]+$' ]]; then
    proxygpt_die "Небезопасное имя удалённого скрипта: ${script_name}"
    return 1
  fi

  remote_script="${remote_stage}/${script_name}"
  if [[ "$admin_user" == "root" ]]; then
    runner="bash"
  else
    runner="sudo -- bash"
  fi

  print -r -- \
    "${runner} '${remote_script}'; exit_code=\$?; if [ \$exit_code -eq 0 ]; then rm -rf -- '${remote_stage}'; fi; exit \$exit_code"
}

proxygpt_remote_execute_staged_script() {
  local script_name="${1:?требуется имя удалённого скрипта}"
  local target="$(proxygpt_remote_admin_target)"
  local ssh_port="$(proxygpt_config_get ssh_port)"
  local host_key_policy="$(proxygpt_config_get ssh_host_key_policy)"
  local control_socket="$(proxygpt_config_get admin_control_socket)"
  local remote_command="$(proxygpt_remote_script_command "$script_name")"
  local exit_code

  proxygpt_admin_master_require

  proxygpt_log INFO "Запускается подготовленный скрипт настройки сервера"

  if ssh \
    -t \
    -S "$control_socket" \
    -o ControlMaster=auto \
    -o "StrictHostKeyChecking=${host_key_policy}" \
    -p "$ssh_port" \
    "$target" \
    "$remote_command"; then
    exit_code=0
  else
    exit_code=$?
  fi

  if (( exit_code != 0 )); then
    proxygpt_die "Удалённая настройка сервера завершилась с кодом ${exit_code}; временный каталог сохранён: ${remote_stage}"
    return "$exit_code"
  fi

  proxygpt_config_set remote_stage_dir ""
  proxygpt_success "Удалённая настройка сервера завершена"
}
