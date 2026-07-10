# Exact-path local removal used by the interactive uninstaller.

proxygpt_remove_configured_path() {
  local item_path="${1:?configured removal path is required}"
  local parent_directory="${item_path:h}"

  [[ -e "$item_path" || -L "$item_path" ]] || return 0

  if [[ -w "$parent_directory" ]]; then
    command rm -rf -- "$item_path" || return 1
  else
    command sudo rm -rf -- "$item_path" || return 1
  fi
}
