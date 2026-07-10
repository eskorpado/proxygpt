# Installation of the prebuilt bundled ProxyGPT ICNS asset.

proxygpt_validate_bundled_icon() {
  local source_icon="$(proxygpt_config_get icon_source)"
  local magic_output
  local -a magic_bytes

  if [[ ! -s "$source_icon" ]]; then
    proxygpt_die "Bundled ProxyGPT ICNS is missing or empty: ${source_icon}"
    return 1
  fi

  magic_output="$(od -An -N4 -t x1 "$source_icon")"
  magic_bytes=("${(z)magic_output}")

  if [[ "${(j::)magic_bytes}" != "69636e73" ]]; then
    proxygpt_die "Bundled icon is not a valid ICNS container: ${source_icon}"
    return 1
  fi
}

proxygpt_install_bundled_icns() {
  local destination="${1:?ICNS destination path is required}"
  local source_icon="$(proxygpt_config_get icon_source)"

  if [[ "$destination" != /* || "$destination" != *.icns ]]; then
    proxygpt_die "ICNS destination must be an absolute .icns path: ${destination}"
    return 1
  fi

  proxygpt_validate_bundled_icon

  mkdir -p "${destination:h}"
  cp -p "$source_icon" "$destination"
  chmod 644 "$destination"

  if ! cmp -s "$source_icon" "$destination"; then
    proxygpt_die "Installed ICNS does not match the bundled asset: ${destination}"
    return 1
  fi

  proxygpt_success "Bundled app icon installed: ${destination}"
}
