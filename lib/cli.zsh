# Installation of the user-facing proxygpt command symlink.

proxygpt_cli_run_for_directory() {
  local directory="${1:?directory is required}"
  shift

  if [[ -w "$directory" ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

proxygpt_cli_ensure_directory() {
  local directory="${1:?directory is required}"
  local parent="${directory:h}"

  if [[ -d "$directory" ]]; then
    return 0
  fi

  if [[ ! -d "$parent" ]]; then
    proxygpt_die "Parent directory does not exist: ${parent}"
    return 1
  fi

  if [[ -w "$parent" ]]; then
    mkdir "$directory"
  else
    sudo mkdir "$directory"
  fi
}

proxygpt_cli_link_matches() {
  local link_path="${1:?link path is required}"
  local expected_target="${2:?expected target is required}"
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
    proxygpt_die "Runtime command is missing or not executable: ${target}"
    return 1
  fi

  proxygpt_cli_ensure_directory "$link_directory"

  if proxygpt_cli_link_matches "$link_path" "$target"; then
    proxygpt_success "Command link is already installed: ${link_path}"
    return 0
  fi

  if [[ -e "$link_path" || -L "$link_path" ]]; then
    if [[ -d "$link_path" && ! -L "$link_path" ]]; then
      proxygpt_die "Cannot replace a directory with the command link: ${link_path}"
      return 1
    fi

    proxygpt_prompt_menu \
      "Another file already exists at ${link_path}:" \
      "Replace it" \
      "Abort"

    if [[ "$PROXYGPT_REPLY" != "1" ]]; then
      proxygpt_die "Command link installation aborted"
      return 1
    fi

    proxygpt_cli_run_for_directory "$link_directory" rm -f "$link_path"
  fi

  proxygpt_cli_run_for_directory "$link_directory" ln -s "$target" "$link_path"

  if ! proxygpt_cli_link_matches "$link_path" "$target"; then
    proxygpt_die "Command link validation failed: ${link_path}"
    return 1
  fi

  proxygpt_success "Command installed: ${link_path}"
}
