# Target macOS application discovery and validation.

proxygpt_expand_user_path() {
  local path="${1:?path is required}"

  if [[ "$path" == "~" ]]; then
    path="$HOME"
  elif [[ "$path" == "~/"* ]]; then
    path="${HOME}/${path#\~/}"
  fi

  print -r -- "$path"
}

proxygpt_find_target_app() {
  local requested="${1:?application name or path is required}"
  local candidate
  local app_name
  local -a candidates

  if [[ "$requested" == /* || "$requested" == "~/"* ]]; then
    candidate="$(proxygpt_expand_user_path "$requested")"
    [[ -d "$candidate" ]] || return 1
    print -r -- "${candidate:A}"
    return 0
  fi

  app_name="${requested%.app}"
  candidates=(
    "/Applications/${app_name}.app"
    "${HOME}/Applications/${app_name}.app"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      print -r -- "${candidate:A}"
      return 0
    fi
  done

  return 1
}

proxygpt_read_bundle_executable() {
  local bundle="${1:?application bundle path is required}"
  local plist="${bundle}/Contents/Info.plist"
  local executable

  if [[ ! -f "$plist" ]]; then
    proxygpt_die "Application bundle has no Contents/Info.plist: ${bundle}"
    return 1
  fi

  if ! plutil -lint "$plist" >/dev/null; then
    proxygpt_die "Application Info.plist is invalid: ${plist}"
    return 1
  fi

  if ! executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null)"; then
    proxygpt_die "CFBundleExecutable is missing from: ${plist}"
    return 1
  fi

  if [[ -z "$executable" ]]; then
    proxygpt_die "CFBundleExecutable is empty in: ${plist}"
    return 1
  fi

  print -r -- "$executable"
}

proxygpt_validate_target_app() {
  local bundle="${1:?application bundle path is required}"
  local executable
  local executable_path

  if [[ ! -d "$bundle" ]]; then
    proxygpt_die "Application bundle does not exist: ${bundle}"
    return 1
  fi

  if [[ "$bundle" != *.app ]]; then
    proxygpt_die "Target must be a macOS .app bundle: ${bundle}"
    return 1
  fi

  if ! executable="$(proxygpt_read_bundle_executable "$bundle")"; then
    return 1
  fi

  executable_path="${bundle}/Contents/MacOS/${executable}"
  if [[ ! -x "$executable_path" ]]; then
    proxygpt_die "Bundle executable is missing or not executable: ${executable_path}"
    return 1
  fi

  print -r -- "$executable_path"
}

proxygpt_configure_target_app() {
  local requested="${1:?application name or path is required}"
  local profile_id="${2:?output profile id is required}"
  local bundle
  local executable_path

  if ! bundle="$(proxygpt_find_target_app "$requested")"; then
    return 1
  fi

  if ! executable_path="$(proxygpt_validate_target_app "$bundle")"; then
    return 1
  fi

  proxygpt_config_set target_app_name "${bundle:t:r}"
  proxygpt_config_set target_app_path "$bundle"
  proxygpt_config_set target_app_executable "$executable_path"
  proxygpt_configure_profile "$profile_id"
}

proxygpt_prompt_target_app() {
  local known_name
  local bundle
  local requested
  local selection
  local -a known_bundles=()
  local -a known_profiles=()
  local -a menu_options=()
  local -A seen_bundles=()

  for known_name in ChatGPT Codex Claude; do
    if bundle="$(proxygpt_find_target_app "$known_name")"; then
      if [[ -z "${seen_bundles[$bundle]-}" ]]; then
        known_bundles+=("$bundle")
        known_profiles+=("${known_name:l}")
        menu_options+=("${bundle:t} — ${bundle}")
        seen_bundles[$bundle]=1
      fi
    fi
  done

  if (( ${#known_bundles} > 0 )); then
    menu_options+=("Other application name or full .app path")
    proxygpt_prompt_menu "Target application:" "${menu_options[@]}"
    selection="$PROXYGPT_REPLY"

    if (( selection <= ${#known_bundles} )); then
      proxygpt_configure_target_app "${known_bundles[selection]}" "${known_profiles[selection]}"
      return
    fi
  fi

  while true; do
    proxygpt_prompt_nonempty "Application name or full .app path"
    requested="$PROXYGPT_REPLY"

    if proxygpt_configure_target_app "$requested" llm; then
      return 0
    fi

    proxygpt_warn "Application was not found or is not a valid macOS app bundle"
  done
}

proxygpt_target_app_is_running() {
  local executable="$(proxygpt_config_get target_app_executable)"
  local process_name="${executable:t}"
  local running_command

  while IFS= read -r running_command; do
    if [[ "${running_command:t}" == "$process_name" ]]; then
      return 0
    fi
  done < <(/bin/ps -axo comm= 2>/dev/null)

  return 1
}
