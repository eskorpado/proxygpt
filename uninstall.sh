#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r ROOT="${0:A:h}"
typeset -r REMOTE_SCRIPT="${ROOT}/templates/remote/uninstall-user.sh"

source "${ROOT}/lib/ui.zsh"
source "${ROOT}/lib/input.zsh"
source "${ROOT}/lib/profile.zsh"
source "${ROOT}/lib/uninstall_local.zsh"

typeset -g DEFAULT_MANIFEST=""
typeset -g UNINSTALL_PROFILE_ID=""
typeset -g UNINSTALL_PRODUCT_NAME=""
typeset -g UNINSTALL_CLI_NAME=""
typeset -g UNINSTALL_BUNDLE_ID=""

uninstall_die() {
  proxygpt_error "$1"
  return 1
}

select_installed_profile() {
  local profile_id product_name cli_name bundle_id manifest_path selection
  local -a installed_ids=()
  local -a options=()

  for profile_id in "${PROXYGPT_PROFILE_IDS[@]}"; do
    product_name="$(proxygpt_profile_field "$profile_id" product)"
    cli_name="$(proxygpt_profile_field "$profile_id" cli)"
    bundle_id="$(proxygpt_profile_field "$profile_id" bundle_id)"
    manifest_path="${HOME}/Library/Application Support/${product_name}/config/install-manifest.conf"
    if [[ -e "$manifest_path" || -L "$manifest_path" ]] && (
      DEFAULT_MANIFEST="$manifest_path"
      UNINSTALL_PROFILE_ID="$profile_id"
      UNINSTALL_PRODUCT_NAME="$product_name"
      UNINSTALL_CLI_NAME="$cli_name"
      UNINSTALL_BUNDLE_ID="$bundle_id"
      validate_manifest >/dev/null 2>&1
    ); then
      installed_ids+=("$profile_id")
      options+=("${product_name} — ${manifest_path}")
    fi
  done

  if (( ${#installed_ids} == 0 )); then
    uninstall_die "No profiles with a valid schema-2 manifest were found"
    return 1
  fi

  proxygpt_prompt_menu "Profile to uninstall:" "${options[@]}"
  selection="$PROXYGPT_REPLY"
  UNINSTALL_PROFILE_ID="${installed_ids[selection]}"
  UNINSTALL_PRODUCT_NAME="$(proxygpt_profile_field "$UNINSTALL_PROFILE_ID" product)"
  UNINSTALL_CLI_NAME="$(proxygpt_profile_field "$UNINSTALL_PROFILE_ID" cli)"
  UNINSTALL_BUNDLE_ID="$(proxygpt_profile_field "$UNINSTALL_PROFILE_ID" bundle_id)"
  DEFAULT_MANIFEST="${HOME}/Library/Application Support/${UNINSTALL_PRODUCT_NAME}/config/install-manifest.conf"
}

validate_manifest() {
  [[ -r "$DEFAULT_MANIFEST" ]] || {
    print -ru2 -- "Installation manifest is missing: ${DEFAULT_MANIFEST}"
    print -ru2 -- "No files were removed. Remove the configured app, command link, data directory, and key pair manually."
    return 1
  }

  zsh -n "$DEFAULT_MANIFEST" || return 1
  source "$DEFAULT_MANIFEST"

  local name
  for name in MANIFEST_SCHEMA PROFILE_ID PRODUCT_NAME CLI_NAME BUNDLE_ID \
              SERVER ADMIN_USER SSH_PORT SSH_HOST_KEY_POLICY TUNNEL_USER \
              SSH_KEY LOCAL_PORT CONTROL_DIR CONTROL_SOCKET DATA_ROOT RUNTIME_COMMAND CLI_LINK APP_PATH; do
    [[ -n "${(P)name:-}" ]] || uninstall_die "Manifest value is missing: ${name}" || return 1
  done

  [[ "$MANIFEST_SCHEMA" == 2 ]] || uninstall_die "Unsupported manifest schema" || return 1
  [[ "$PROFILE_ID" == "$UNINSTALL_PROFILE_ID" ]] || uninstall_die "Manifest profile mismatch" || return 1
  [[ "$PRODUCT_NAME" == "$UNINSTALL_PRODUCT_NAME" ]] || uninstall_die "Manifest product mismatch" || return 1
  [[ "$CLI_NAME" == "$UNINSTALL_CLI_NAME" ]] || uninstall_die "Manifest CLI mismatch" || return 1
  [[ "$BUNDLE_ID" == "$UNINSTALL_BUNDLE_ID" ]] || uninstall_die "Manifest bundle identifier mismatch" || return 1
  [[ "$SERVER" =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]] || uninstall_die "Unsafe server value" || return 1
  [[ "$ADMIN_USER" =~ '^[A-Za-z_][A-Za-z0-9._-]*$' ]] || uninstall_die "Unsafe admin username" || return 1
  [[ "$TUNNEL_USER" =~ '^[a-z_][a-z0-9_-]{0,31}$' && "$TUNNEL_USER" != root ]] || uninstall_die "Unsafe tunnel username" || return 1
  [[ "$SSH_PORT" == <-> && "$SSH_PORT" -ge 1 && "$SSH_PORT" -le 65535 ]] || uninstall_die "Unsafe SSH port" || return 1
  [[ "$LOCAL_PORT" == <-> && "$LOCAL_PORT" -ge 1 && "$LOCAL_PORT" -le 65535 ]] || uninstall_die "Unsafe local port" || return 1
  [[ "$SSH_KEY" == /* && "$SSH_KEY" != *.pub && "${SSH_KEY:h}" != / ]] || uninstall_die "Unsafe SSH key path" || return 1
  [[ "$DATA_ROOT" == "${HOME}/Library/Application Support/${UNINSTALL_PRODUCT_NAME}" ]] || uninstall_die "Unexpected data root" || return 1
  [[ "$RUNTIME_COMMAND" == "${DATA_ROOT}/bin/${UNINSTALL_CLI_NAME}" ]] || uninstall_die "Unexpected runtime command" || return 1
  [[ "$CONTROL_DIR" == "${HOME}/.ssh/control" ]] || uninstall_die "Unexpected control directory" || return 1
  [[ "$CONTROL_SOCKET" == "${CONTROL_DIR}/${UNINSTALL_CLI_NAME}-${LOCAL_PORT}.sock" ]] || uninstall_die "Unexpected control socket" || return 1
  [[ "$CLI_LINK" == "/usr/local/bin/${UNINSTALL_CLI_NAME}" ]] || uninstall_die "Unexpected command link" || return 1
  [[ "$APP_PATH" == /* && "${APP_PATH:t}" == "${UNINSTALL_PRODUCT_NAME}.app" && "${APP_PATH:h}" != / ]] || uninstall_die "Unexpected app path" || return 1
  [[ "$SSH_HOST_KEY_POLICY" == accept-new ]] || uninstall_die "Unexpected host-key policy" || return 1
  [[ -f "$REMOTE_SCRIPT" ]] || uninstall_die "Remote uninstall template is missing" || return 1
}

stop_tunnel_before_removal() {
  local tunnel_command="${RUNTIME_COMMAND:h}/proxygpt-tunnel"

  if [[ -x "$tunnel_command" ]]; then
    "$tunnel_command" stop || uninstall_die "Tunnel could not be stopped; nothing was removed"
    return
  fi

  if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1 || [[ -e "$CONTROL_SOCKET" || -L "$CONTROL_SOCKET" ]]; then
    uninstall_die "Tunnel manager is missing while its listener or socket may remain; nothing was removed"
    return 1
  fi
}

remove_server_user() {
  local target="${ADMIN_USER}@${SERVER}"
  local control_dir control_socket remote_stage remote_command runner
  local operation_status=0
  local cleanup_status=0

  control_dir="$(mktemp -d /tmp/proxygpt-uninstall-admin.XXXXXXXX)" || return 1
  chmod 700 "$control_dir" || return 1
  control_socket="${control_dir}/master.sock"

  if ! ssh -M -S "$control_socket" -f -N \
    -o "StrictHostKeyChecking=${SSH_HOST_KEY_POLICY}" \
    -o ControlPersist=300 \
    -p "$SSH_PORT" "$target"; then
    rmdir "$control_dir" 2>/dev/null || true
    return 1
  fi

  if ! remote_stage="$(ssh -S "$control_socket" -p "$SSH_PORT" "$target" \
    'umask 077; mktemp -d /tmp/proxygpt-uninstall.XXXXXXXX')"; then
    operation_status=$?
    (( operation_status == 0 )) && operation_status=1
  elif [[ ! "$remote_stage" =~ '^/tmp/proxygpt-uninstall\.[A-Za-z0-9]+$' ]]; then
    proxygpt_error "Unexpected remote staging path"
    operation_status=1
  fi

  if (( operation_status == 0 )); then
    if ! scp -o "ControlPath=${control_socket}" -P "$SSH_PORT" -- \
      "$REMOTE_SCRIPT" "${target}:${remote_stage}/uninstall-user.sh"; then
      operation_status=$?
      (( operation_status == 0 )) && operation_status=1
    fi
  fi

  if (( operation_status == 0 )); then
    if [[ "$ADMIN_USER" == root ]]; then
      runner="bash"
    else
      runner="sudo -- bash"
    fi
    remote_command="${runner} '${remote_stage}/uninstall-user.sh' '${TUNNEL_USER}'; status=\$?; rm -rf -- '${remote_stage}'; exit \$status"
    if ssh -t -S "$control_socket" -p "$SSH_PORT" "$target" "$remote_command"; then
      remote_stage=""
    else
      operation_status=$?
      remote_stage=""
    fi
  elif [[ -n "$remote_stage" && "$remote_stage" =~ '^/tmp/proxygpt-uninstall\.[A-Za-z0-9]+$' ]]; then
    ssh -S "$control_socket" -p "$SSH_PORT" "$target" "rm -rf -- '${remote_stage}'" || cleanup_status=$?
  fi

  ssh -S "$control_socket" -O exit -p "$SSH_PORT" "$target" >/dev/null || cleanup_status=$?
  rmdir "$control_dir" || cleanup_status=$?

  (( operation_status == 0 )) || return "$operation_status"
  (( cleanup_status == 0 )) || return "$cleanup_status"
}

select_installed_profile
validate_manifest

proxygpt_prompt_menu "Uninstall scope:" \
  "Local macOS components only" \
  "Local macOS components and tunnel account on the server"
typeset -r SCOPE="$PROXYGPT_REPLY"

proxygpt_prompt_menu "Local SSH key pair:" \
  "Keep ${SSH_KEY} and ${SSH_KEY}.pub" \
  "Delete ${SSH_KEY} and ${SSH_KEY}.pub"
typeset -r DELETE_KEY="$([[ "$PROXYGPT_REPLY" == 2 ]] && print yes || print no)"

print
print -r -- "Removal summary:"
print -r -- "  Scope: $([[ "$SCOPE" == 2 ]] && print 'local + server' || print 'local only')"
print -r -- "  App: ${APP_PATH}"
print -r -- "  Command: ${CLI_LINK}"
print -r -- "  Data: ${DATA_ROOT}"
print -r -- "  SSH key pair: $([[ "$DELETE_KEY" == yes ]] && print delete || print preserve)"
[[ "$SCOPE" == 2 ]] && print -r -- "  SERVER ACCOUNT AND HOME: ${TUNNEL_USER}@${SERVER}"
print
proxygpt_prompt_menu "Proceed with permanent removal?" "Remove" "Abort"
[[ "$PROXYGPT_REPLY" == 1 ]] || { proxygpt_warn "Uninstall cancelled; nothing was removed"; exit 130; }

stop_tunnel_before_removal || exit $?
if [[ "$SCOPE" == 2 ]]; then
  remove_server_user || exit $?
fi

proxygpt_remove_configured_path "$APP_PATH" || exit $?
proxygpt_remove_configured_path "$CLI_LINK" || exit $?
if [[ "$DELETE_KEY" == yes ]]; then
  rm -f -- "$SSH_KEY" "${SSH_KEY}.pub" || exit $?
fi
proxygpt_remove_configured_path "$DATA_ROOT" || exit $?

proxygpt_success "${UNINSTALL_PRODUCT_NAME} uninstall completed"
