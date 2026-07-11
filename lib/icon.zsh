# Установка готового ICNS-ресурса из комплекта.

proxygpt_validate_bundled_icon() {
  local source_icon="$(proxygpt_config_get icon_source)"
  local magic_output
  local -a magic_bytes

  if [[ ! -s "$source_icon" ]]; then
    proxygpt_die "ICNS из комплекта отсутствует или пуст: ${source_icon}"
    return 1
  fi

  magic_output="$(od -An -N4 -t x1 "$source_icon")"
  magic_bytes=("${(z)magic_output}")

  if [[ "${(j::)magic_bytes}" != "69636e73" ]]; then
    proxygpt_die "Иконка из комплекта не является корректным контейнером ICNS: ${source_icon}"
    return 1
  fi
}

proxygpt_install_bundled_icns() {
  local destination="${1:?требуется путь назначения ICNS}"
  local source_icon="$(proxygpt_config_get icon_source)"

  if [[ "$destination" != /* || "$destination" != *.icns ]]; then
    proxygpt_die "Путь назначения ICNS должен быть абсолютным и оканчиваться на .icns: ${destination}"
    return 1
  fi

  proxygpt_validate_bundled_icon

  mkdir -p "${destination:h}"
  cp -p "$source_icon" "$destination"
  chmod 644 "$destination"

  if ! cmp -s "$source_icon" "$destination"; then
    proxygpt_die "Установленный ICNS не совпадает с ресурсом из комплекта: ${destination}"
    return 1
  fi

  proxygpt_success "Иконка приложения установлена: ${destination}"
}
