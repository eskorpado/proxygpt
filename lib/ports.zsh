# Проверка TCP-портов и обработка локальных конфликтов при установке.

proxygpt_port_is_valid() {
  local port="${1-}"
  [[ "$port" == <-> ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

proxygpt_local_port_listener_details() {
  local port="${1:?требуется локальный порт}"

  proxygpt_port_is_valid "$port" || return 1
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null
}

proxygpt_local_port_is_in_use() {
  local port="${1:?требуется локальный порт}"
  local details

  if ! details="$(proxygpt_local_port_listener_details "$port")"; then
    return 1
  fi
  [[ -n "$details" ]]
}

proxygpt_random_free_local_port() {
  local candidate
  local attempt

  for (( attempt = 1; attempt <= 128; attempt++ )); do
    candidate=$(( 49152 + ((((RANDOM << 15) | RANDOM)) % 16384) ))
    if ! proxygpt_local_port_is_in_use "$candidate"; then
      print -r -- "$candidate"
      return 0
    fi
  done

  proxygpt_die "Не удалось выбрать свободный случайный локальный порт из диапазона 49152–65535"
  return 1
}

proxygpt_prompt_local_proxy_port() {
  local default_port="$(proxygpt_config_get local_proxy_port)"
  local selected_port
  local details

  if [[ -z "$default_port" ]]; then
    default_port="$(proxygpt_random_free_local_port)" || return 1
    proxygpt_config_set local_proxy_port "$default_port"
  fi

  while true; do
    proxygpt_prompt_nonempty "Локальный порт прокси" "$default_port"
    selected_port="$PROXYGPT_REPLY"

    if ! proxygpt_port_is_valid "$selected_port"; then
      proxygpt_warn "Порт должен быть целым числом от 1 до 65535"
      continue
    fi

    if proxygpt_local_port_is_in_use "$selected_port"; then
      proxygpt_warn "Локальный порт ${selected_port} уже занят"
      details="$(proxygpt_local_port_listener_details "$selected_port")"
      print -ru2 -- "$details"
      default_port="$selected_port"
      continue
    fi

    proxygpt_config_set local_proxy_port "$selected_port"
    proxygpt_config_set tunnel_control_socket \
      "$(proxygpt_config_get tunnel_control_dir)/$(proxygpt_config_get cli_name)-${selected_port}.sock"
    proxygpt_success "Локальный порт прокси свободен: ${selected_port}"
    return 0
  done
}
