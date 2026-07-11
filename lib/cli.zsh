# Установка пользовательской символьной ссылки CLI-команды.

proxygpt_cli_run_for_directory() {
  local directory="${1:?требуется каталог}"
  shift

  if [[ -w "$directory" ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

proxygpt_cli_ensure_directory() {
  local directory="${1:?требуется каталог}"
  local parent="${directory:h}"

  if [[ -d "$directory" ]]; then
    return 0
  fi

  if [[ ! -d "$parent" ]]; then
    proxygpt_die "Родительский каталог не существует: ${parent}"
    return 1
  fi

  if [[ -w "$parent" ]]; then
    mkdir "$directory"
  else
    sudo mkdir "$directory"
  fi
}

proxygpt_cli_link_matches() {
  local link_path="${1:?требуется путь ссылки}"
  local expected_target="${2:?требуется ожидаемая цель}"
  local current_target

  [[ -L "$link_path" ]] || return 1
  current_target="$(readlink "$link_path")" || return 1

  if [[ "$current_target" != /* ]]; then
    current_target="${link_path:h}/${current_target}"
  fi

  [[ "${current_target:A}" == "${expected_target:A}" ]]
}

proxygpt_install_cli_link() {
  local target="$(proxygpt_config_get runtime_command)"
  local link_path="$(proxygpt_config_get cli_link_path)"
  local link_directory="${link_path:h}"

  if [[ ! -x "$target" ]]; then
    proxygpt_die "Команда среды выполнения отсутствует или недоступна: ${target}"
    return 1
  fi

  proxygpt_cli_ensure_directory "$link_directory"

  if proxygpt_cli_link_matches "$link_path" "$target"; then
    proxygpt_success "Ссылка команды уже установлена: ${link_path}"
    return 0
  fi

  if [[ -e "$link_path" || -L "$link_path" ]]; then
    if [[ -d "$link_path" && ! -L "$link_path" ]]; then
      proxygpt_die "Нельзя заменить каталог ссылкой команды: ${link_path}"
      return 1
    fi

    proxygpt_prompt_menu \
      "По пути ${link_path} уже находится другой файл:" \
      "Заменить" \
      "Прервать"

    if [[ "$PROXYGPT_REPLY" != "1" ]]; then
      proxygpt_die "Установка ссылки команды прервана"
      return 1
    fi

    proxygpt_cli_run_for_directory "$link_directory" rm -f "$link_path"
  fi

  proxygpt_cli_run_for_directory "$link_directory" ln -s "$target" "$link_path"

  if ! proxygpt_cli_link_matches "$link_path" "$target"; then
    proxygpt_die "Проверка ссылки команды завершилась ошибкой: ${link_path}"
    return 1
  fi

  proxygpt_success "Команда установлена: ${link_path}"
}
