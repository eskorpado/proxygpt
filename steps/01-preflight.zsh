# Этап 1: проверка локального компьютера и сбор параметров установки.

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
    proxygpt_die "Для установщика ProxyGPT v1 требуется macOS"
    return 1
  fi

  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      proxygpt_die "Не найдена обязательная команда: ${tool}"
      return 1
    fi
  done

  if [[ ! -x /usr/libexec/PlistBuddy ]]; then
    proxygpt_die "Обязательная команда недоступна для выполнения: /usr/libexec/PlistBuddy"
    return 1
  fi

  if [[ ! -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]]; then
    proxygpt_die "Не найден обязательный инструмент регистрации Launch Services"
    return 1
  fi

  proxygpt_success "macOS и обязательные локальные команды проверены"
}

proxygpt_prompt_server_host() {
  while true; do
    proxygpt_prompt_nonempty "Имя сервера или SSH-алиас"
    if [[ "$PROXYGPT_REPLY" =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]]; then
      proxygpt_config_set server_host "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Укажите имя сервера или SSH-алиас без пробелов, @, порта и параметров"
  done
}

proxygpt_prompt_admin_user() {
  while true; do
    proxygpt_prompt_nonempty "Имя администратора SSH"
    if [[ "$PROXYGPT_REPLY" =~ '^[A-Za-z_][A-Za-z0-9._-]*$' ]]; then
      proxygpt_config_set admin_user "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Недопустимое имя администратора SSH"
  done
}

proxygpt_prompt_port_config() {
  local label="${1:?требуется название порта}"
  local key="${2:?требуется ключ конфигурации}"
  local default_port="$(proxygpt_config_get "$key")"

  while true; do
    proxygpt_prompt_nonempty "$label" "$default_port"
    if proxygpt_port_is_valid "$PROXYGPT_REPLY"; then
      proxygpt_config_set "$key" "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Порт должен быть целым числом от 1 до 65535"
  done
}

proxygpt_prompt_tunnel_user() {
  local default_user="$(proxygpt_config_get tunnel_user)"

  while true; do
    proxygpt_prompt_nonempty "Имя пользователя туннеля" "$default_user"
    if [[ "$PROXYGPT_REPLY" =~ '^[a-z_][a-z0-9_-]{0,31}$' ]]; then
      proxygpt_config_set tunnel_user "$PROXYGPT_REPLY"
      return 0
    fi
    proxygpt_warn "Используйте 1–32 строчные буквы, цифры, подчёркивания или дефисы"
  done
}

proxygpt_prompt_app_path() {
  local default_path="$(proxygpt_config_get app_path)"
  local product_name="$(proxygpt_config_get product_name)"
  local selected_path

  while true; do
    proxygpt_prompt_nonempty "Расположение приложения ${product_name}" "$default_path"
    selected_path="$(proxygpt_expand_user_path "$PROXYGPT_REPLY")"
    if proxygpt_app_path_is_safe "$selected_path" && \
       [[ "${selected_path:t}" == "${product_name}.app" ]]; then
      proxygpt_config_set app_path "$selected_path"
      return 0
    fi
    proxygpt_warn "Путь должен быть абсолютным и оканчиваться на ${product_name}.app"
    default_path=""
  done
}

proxygpt_print_install_summary() {
  print
  print -r -- "Сводка установки"
  print -r -- "  Выходной профиль: $(proxygpt_config_get product_name)"
  print -r -- "  Целевое приложение: $(proxygpt_config_get target_app_path)"
  print -r -- "  Сервер:           $(proxygpt_config_get admin_user)@$(proxygpt_config_get server_host):$(proxygpt_config_get ssh_port)"
  print -r -- "  Пользователь туннеля: $(proxygpt_config_get tunnel_user)"
  print -r -- "  Удалённый прокси: 127.0.0.1:$(proxygpt_config_get remote_proxy_port)"
  print -r -- "  Локальный прокси: 127.0.0.1:$(proxygpt_config_get local_proxy_port)"
  print -r -- "  Ключ SSH:         $(proxygpt_config_get ssh_key_path) ($(proxygpt_config_get ssh_key_action))"
  print -r -- "  Выходное приложение: $(proxygpt_config_get app_path)"
  print -r -- "  Команда CLI:      $(proxygpt_config_get cli_link_path)"
  print -r -- "  Иконка:           $(proxygpt_config_get icon_source)"
}

proxygpt_step_preflight() {
  proxygpt_preflight_local
  proxygpt_prompt_target_app
  proxygpt_success "Целевое приложение: $(proxygpt_config_get target_app_path)"
  proxygpt_prompt_server_host
  proxygpt_prompt_admin_user
  proxygpt_prompt_port_config "Порт администратора SSH" ssh_port
  proxygpt_prompt_tunnel_user
  proxygpt_prompt_port_config "Удалённый порт Squid" remote_proxy_port
  proxygpt_prompt_local_proxy_port
  proxygpt_prompt_ssh_key_path
  proxygpt_prompt_app_path
  proxygpt_validate_bundled_icon

  proxygpt_print_install_summary
  proxygpt_prompt_yes_no "Продолжить?" yes
  if [[ "$PROXYGPT_REPLY" != "yes" ]]; then
    proxygpt_warn "Установка отменена до внесения изменений"
    return 130
  fi

  proxygpt_log_init
  proxygpt_write_install_manifest || return 1
  proxygpt_success "Установка подтверждена"
}
