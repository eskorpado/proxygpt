# ProxyGPT.app staging, validation, and destination conflict handling.

typeset -gr PROXYGPT_BUNDLE_ID="com.local.proxygpt"
typeset -gr PROXYGPT_LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

proxygpt_app_path_is_safe() {
  local app_path="${1-}"
  [[ "$app_path" == /* && "$app_path" == *.app && "${app_path:h}" != "/" ]]
}

proxygpt_existing_bundle_id() {
  local app_path="${1:?application path is required}"
  local plist="${app_path}/Contents/Info.plist"

  [[ -f "$plist" ]] || return 1
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null
}

proxygpt_validate_app_bundle() {
  local app_path="${1:?application path is required}"
  local plist="${app_path}/Contents/Info.plist"
  local launcher="${app_path}/Contents/MacOS/launcher"
  local icon="${app_path}/Contents/Resources/ProxyGPT.icns"
  local bundle_id

  if ! proxygpt_app_path_is_safe "$app_path" || [[ ! -d "$app_path" ]]; then
    proxygpt_die "Invalid ProxyGPT app bundle path: ${app_path}"
    return 1
  fi

  if ! plutil -lint "$plist" >/dev/null; then
    proxygpt_die "ProxyGPT Info.plist is invalid: ${plist}"
    return 1
  fi

  bundle_id="$(proxygpt_existing_bundle_id "$app_path")" || {
    proxygpt_die "ProxyGPT bundle identifier is missing"
    return 1
  }

  if [[ "$bundle_id" != "$PROXYGPT_BUNDLE_ID" ]]; then
    proxygpt_die "Unexpected ProxyGPT bundle identifier: ${bundle_id}"
    return 1
  fi

  if [[ ! -x "$launcher" ]]; then
    proxygpt_die "ProxyGPT bundle launcher is missing or not executable"
    return 1
  fi

  if ! cmp -s "$(proxygpt_config_get icon_source)" "$icon"; then
    proxygpt_die "ProxyGPT bundle icon does not match the bundled asset"
    return 1
  fi
}

proxygpt_build_staged_app_bundle() {
  local destination="$(proxygpt_config_get app_path)"
  local destination_parent="${destination:h}"
  local stage_root
  local staged_app

  if ! proxygpt_app_path_is_safe "$destination"; then
    proxygpt_die "Unsafe ProxyGPT app destination: ${destination}"
    return 1
  fi

  if ! mkdir -p "$destination_parent"; then
    proxygpt_die "Could not create app destination directory: ${destination_parent}"
    return 1
  fi

  if ! stage_root="$(mktemp -d "${destination_parent}/.proxygpt-app-stage.XXXXXXXX")"; then
    proxygpt_die "Could not create ProxyGPT app staging directory"
    return 1
  fi

  if [[ "${stage_root:h}" != "$destination_parent" || \
        ! "${stage_root:t}" =~ '^\.proxygpt-app-stage\.[A-Za-z0-9]+$' ]]; then
    proxygpt_die "Unexpected ProxyGPT app staging path: ${stage_root}"
    return 1
  fi

  staged_app="${stage_root}/ProxyGPT.app"
  if ! mkdir -p \
    "${staged_app}/Contents/MacOS" \
    "${staged_app}/Contents/Resources"; then
    proxygpt_die "Could not create staged app bundle directories"
    return 1
  fi

  if ! cp "${PROXYGPT_ROOT}/templates/app/Info.plist" \
    "${staged_app}/Contents/Info.plist"; then
    proxygpt_die "Could not stage ProxyGPT Info.plist"
    return 1
  fi
  if ! cp "${PROXYGPT_ROOT}/templates/app/launcher" \
    "${staged_app}/Contents/MacOS/launcher"; then
    proxygpt_die "Could not stage ProxyGPT app launcher"
    return 1
  fi
  if ! chmod 755 "${staged_app}/Contents/MacOS/launcher"; then
    proxygpt_die "Could not set ProxyGPT launcher permissions"
    return 1
  fi
  if ! proxygpt_install_bundled_icns \
    "${staged_app}/Contents/Resources/ProxyGPT.icns" \
    >/dev/null; then
    return 1
  fi

  if ! proxygpt_validate_app_bundle "$staged_app"; then
    return 1
  fi
  print -r -- "$staged_app"
}

proxygpt_confirm_app_destination() {
  local destination="$(proxygpt_config_get app_path)"
  local existing_id=""

  if [[ ! -e "$destination" && ! -L "$destination" ]]; then
    return 0
  fi

  existing_id="$(proxygpt_existing_bundle_id "$destination")" || true
  if [[ "$existing_id" == "$PROXYGPT_BUNDLE_ID" ]]; then
    return 0
  fi

  proxygpt_prompt_menu \
    "Another item already exists at ${destination}:" \
    "Replace it" \
    "Abort"

  if [[ "$PROXYGPT_REPLY" != "1" ]]; then
    proxygpt_die "ProxyGPT app installation aborted"
    return 1
  fi
}

proxygpt_install_app_bundle() {
  local destination="$(proxygpt_config_get app_path)"
  local destination_parent="${destination:h}"
  local staged_app
  local stage_root
  local old_path="${destination_parent}/.proxygpt-app-old.$$"

  if ! proxygpt_app_path_is_safe "$destination"; then
    proxygpt_die "Unsafe ProxyGPT app destination: ${destination}"
    return 1
  fi

  if ! proxygpt_confirm_app_destination; then
    return 1
  fi
  if ! staged_app="$(proxygpt_build_staged_app_bundle)"; then
    return 1
  fi
  stage_root="${staged_app:h}"

  if [[ -e "$old_path" || -L "$old_path" ]]; then
    proxygpt_die "Temporary old-app path is already occupied: ${old_path}"
    return 1
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    if ! mv "$destination" "$old_path"; then
      proxygpt_die "Could not move the existing app aside: ${destination}"
      return 1
    fi
  fi

  if ! mv "$staged_app" "$destination"; then
    proxygpt_die "Could not install the staged app at: ${destination}"
    return 1
  fi
  if ! proxygpt_validate_app_bundle "$destination"; then
    return 1
  fi

  if [[ -e "$old_path" || -L "$old_path" ]]; then
    if ! rm -rf "$old_path"; then
      proxygpt_die "Installed app is valid, but the old item could not be removed: ${old_path}"
      return 1
    fi
  fi
  if ! rmdir "$stage_root"; then
    proxygpt_die "Installed app is valid, but staging cleanup failed: ${stage_root}"
    return 1
  fi

  proxygpt_success "ProxyGPT app installed: ${destination}"
}

proxygpt_register_app_bundle() {
  local app_path="$(proxygpt_config_get app_path)"

  if ! proxygpt_validate_app_bundle "$app_path"; then
    return 1
  fi

  if [[ ! -x "$PROXYGPT_LSREGISTER" ]]; then
    proxygpt_die "Launch Services registration tool is missing: ${PROXYGPT_LSREGISTER}"
    return 1
  fi

  if ! touch "$app_path"; then
    proxygpt_die "Could not update app bundle timestamp: ${app_path}"
    return 1
  fi

  if ! "$PROXYGPT_LSREGISTER" -f "$app_path"; then
    proxygpt_die "Launch Services registration failed: ${app_path}"
    return 1
  fi

  if ! killall Dock >/dev/null 2>&1; then
    proxygpt_warn "ProxyGPT.app is registered, but Dock could not be restarted"
  else
    proxygpt_success "Dock restarted"
  fi

  proxygpt_success "ProxyGPT.app registered with Launch Services"
}
