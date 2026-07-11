# Работа с отдельной незашифрованной учётной записью Ed25519 для туннеля.

proxygpt_ssh_key_fingerprint() {
  local public_key="${1:?требуется путь открытого ключа}"
  local fingerprint_line
  local -a fields

  if [[ ! -f "$public_key" ]]; then
    proxygpt_die "Открытый ключ SSH отсутствует: ${public_key}"
    return 1
  fi

  if ! fingerprint_line="$(ssh-keygen -lf "$public_key")"; then
    proxygpt_die "Не удалось прочитать fingerprint ключа SSH: ${public_key}"
    return 1
  fi

  fields=("${(z)fingerprint_line}")
  if (( ${#fields} < 2 )); then
    proxygpt_die "Неожиданный формат fingerprint от ssh-keygen"
    return 1
  fi

  print -r -- "${fields[2]}"
}

proxygpt_read_public_key_line() {
  local public_key="${1:?требуется путь открытого ключа}"
  local key_line
  local -a fields

  if [[ ! -f "$public_key" ]]; then
    proxygpt_die "Открытый ключ SSH отсутствует: ${public_key}"
    return 1
  fi

  key_line="$(<"$public_key")"
  if [[ -z "$key_line" || "$key_line" == *$'\n'* ]]; then
    proxygpt_die "Открытый ключ SSH должен содержать ровно одну непустую строку"
    return 1
  fi

  fields=("${(z)key_line}")
  if (( ${#fields} < 2 )) || [[ "${fields[1]}" != "ssh-ed25519" ]]; then
    proxygpt_die "Строка открытого ключа SSH не является чистым ключом Ed25519"
    return 1
  fi

  print -r -- "$key_line"
}

proxygpt_ssh_key_is_unencrypted_ed25519() {
  local private_key="${1:?требуется путь закрытого ключа}"
  local public_key="${private_key}.pub"
  local key_type

  [[ -f "$private_key" && -f "$public_key" ]] || return 1

  if ! ssh-keygen -y -P "" -f "$private_key" >/dev/null 2>&1; then
    return 1
  fi

  IFS=' ' read -r key_type _ < "$public_key" || return 1
  [[ "$key_type" == "ssh-ed25519" ]]
}

proxygpt_prompt_ssh_key_path() {
  local default_path="$(proxygpt_config_get ssh_key_path)"
  local selected_path
  local public_key

  while true; do
    proxygpt_prompt_nonempty "Путь к ключу SSH" "$default_path"
    selected_path="$(proxygpt_expand_user_path "$PROXYGPT_REPLY")"

    if [[ "$selected_path" != /* ]]; then
      proxygpt_warn "Путь к ключу SSH должен быть абсолютным или начинаться с ~/"
      default_path=""
      continue
    fi

    if [[ "$selected_path" == *.pub ]]; then
      proxygpt_warn "Введите путь к закрытому ключу без суффикса .pub"
      default_path=""
      continue
    fi

    selected_path="${selected_path:A}"
    public_key="${selected_path}.pub"

    if [[ ! -e "$selected_path" && ! -e "$public_key" ]]; then
      proxygpt_config_set ssh_key_path "$selected_path"
      proxygpt_config_set ssh_key_action "generate"
      proxygpt_info "Будет создан новый незашифрованный ключ Ed25519"
      return 0
    fi

    if proxygpt_ssh_key_is_unencrypted_ed25519 "$selected_path"; then
      proxygpt_config_set ssh_key_path "$selected_path"
      proxygpt_config_set ssh_key_action "reuse"
      proxygpt_success "Будет повторно использован существующий незашифрованный ключ Ed25519"
      return 0
    fi

    proxygpt_warn \
      "По указанному пути нет полной незашифрованной пары Ed25519; выберите другой путь"
    default_path=""
  done
}

proxygpt_generate_ssh_key() {
  local private_key="$(proxygpt_config_get ssh_key_path)"
  local public_key="${private_key}.pub"
  local key_directory="${private_key:h}"
  local server_host="$(proxygpt_config_get server_host)"
  local cli_name="$(proxygpt_config_get cli_name)"
  local fingerprint

  if [[ "$private_key" != /* ]]; then
    proxygpt_die "Путь к ключу SSH должен быть абсолютным: ${private_key}"
    return 1
  fi

  if [[ -e "$private_key" || -e "$public_key" ]]; then
    proxygpt_die "Отказ от перезаписи существующего пути ключа SSH: ${private_key}"
    return 1
  fi

  if [[ ! -d "$key_directory" ]]; then
    mkdir -p -m 700 "$key_directory"
  fi

  ssh-keygen \
    -q \
    -t ed25519 \
    -N "" \
    -f "$private_key" \
    -C "${cli_name}@${server_host}"

  chmod 600 "$private_key"
  chmod 644 "$public_key"

  if ! proxygpt_ssh_key_is_unencrypted_ed25519 "$private_key"; then
    proxygpt_die "Созданный ключ SSH не прошёл проверку Ed25519 без парольной фразы"
    return 1
  fi

  fingerprint="$(proxygpt_ssh_key_fingerprint "$public_key")"
  proxygpt_success "Создан ключ туннеля Ed25519 (${fingerprint})"
}

proxygpt_prepare_ssh_key() {
  local private_key="$(proxygpt_config_get ssh_key_path)"
  local public_key="${private_key}.pub"
  local expected_action="$(proxygpt_config_get ssh_key_action)"
  local fingerprint

  case "$expected_action" in
    reuse)
      if ! proxygpt_ssh_key_is_unencrypted_ed25519 "$private_key"; then
        proxygpt_die "Ключ SSH изменился после предварительной проверки: ${private_key}"
        return 1
      fi

      chmod 600 "$private_key"
      chmod 644 "$public_key"
      fingerprint="$(proxygpt_ssh_key_fingerprint "$public_key")"
      proxygpt_success "Повторно используется ключ туннеля Ed25519 (${fingerprint})"
      ;;
    generate)
      if [[ -e "$private_key" || -e "$public_key" ]]; then
        proxygpt_die "Путь ключа SSH оказался занят после предварительной проверки: ${private_key}"
        return 1
      fi
      proxygpt_generate_ssh_key
      ;;
    *)
      proxygpt_die "Действие с ключом SSH не выбрано на этапе предварительной проверки"
      return 1
      ;;
  esac
}

proxygpt_prepare_identity_package() {
  local package_dir
  local public_key="$(proxygpt_config_get ssh_key_path).pub"

  if ! proxygpt_read_public_key_line "$public_key" >/dev/null; then
    return 1
  fi

  package_dir="$(mktemp -d /tmp/proxygpt-identity-package.XXXXXXXX)" || return 1
  if [[ ! "$package_dir" =~ '^/tmp/proxygpt-identity-package\.[A-Za-z0-9]+$' ]]; then
    proxygpt_die "Неожиданный путь локального пакета ключей: ${package_dir}"
    return 1
  fi

  if ! cp "$public_key" "${package_dir}/tunnel-key.pub" ||
     ! cp "${PROXYGPT_ROOT}/templates/remote/server-common.sh" "$package_dir/" ||
     ! cp "${PROXYGPT_ROOT}/templates/remote/install-identity.sh" "$package_dir/"; then
    proxygpt_die "Не удалось собрать локальный пакет ключей: ${package_dir}"
    return 1
  fi

  {
    proxygpt_shell_assignment TUNNEL_USER "$(proxygpt_config_get tunnel_user)"
    proxygpt_shell_assignment SERVER_HOST "$(proxygpt_config_get server_host)"
  } > "${package_dir}/settings.sh" || {
    proxygpt_die "Не удалось записать настройки пакета ключей: ${package_dir}"
    return 1
  }

  if ! chmod 600 "${package_dir}"/* ||
     ! chmod 700 "${package_dir}/install-identity.sh" ||
     ! bash -n "${package_dir}/install-identity.sh" "${package_dir}/server-common.sh" "${package_dir}/settings.sh"; then
    proxygpt_die "Проверка пакета ключей завершилась ошибкой: ${package_dir}"
    return 1
  fi

  proxygpt_config_set local_identity_package_dir "$package_dir" || return 1
}

proxygpt_remove_local_identity_package() {
  local package_dir="$(proxygpt_config_get local_identity_package_dir)"

  [[ "$package_dir" =~ '^/tmp/proxygpt-identity-package\.[A-Za-z0-9]+$' ]] || return 1
  if ! rm -rf "$package_dir"; then
    proxygpt_die "Не удалось удалить локальный пакет ключей: ${package_dir}"
    return 1
  fi
  proxygpt_config_set local_identity_package_dir "" || return 1
}
