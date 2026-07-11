# Dedicated unencrypted Ed25519 tunnel identity helpers.

proxygpt_ssh_key_fingerprint() {
  local public_key="${1:?public key path is required}"
  local fingerprint_line
  local -a fields

  if [[ ! -f "$public_key" ]]; then
    proxygpt_die "SSH public key is missing: ${public_key}"
    return 1
  fi

  if ! fingerprint_line="$(ssh-keygen -lf "$public_key")"; then
    proxygpt_die "Could not read SSH key fingerprint: ${public_key}"
    return 1
  fi

  fields=("${(z)fingerprint_line}")
  if (( ${#fields} < 2 )); then
    proxygpt_die "Unexpected ssh-keygen fingerprint output"
    return 1
  fi

  print -r -- "${fields[2]}"
}

proxygpt_read_public_key_line() {
  local public_key="${1:?public key path is required}"
  local key_line
  local -a fields

  if [[ ! -f "$public_key" ]]; then
    proxygpt_die "SSH public key is missing: ${public_key}"
    return 1
  fi

  key_line="$(<"$public_key")"
  if [[ -z "$key_line" || "$key_line" == *$'\n'* ]]; then
    proxygpt_die "SSH public key must contain exactly one non-empty line"
    return 1
  fi

  fields=("${(z)key_line}")
  if (( ${#fields} < 2 )) || [[ "${fields[1]}" != "ssh-ed25519" ]]; then
    proxygpt_die "SSH public key line is not raw Ed25519 key material"
    return 1
  fi

  print -r -- "$key_line"
}

proxygpt_ssh_key_is_unencrypted_ed25519() {
  local private_key="${1:?private key path is required}"
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
    proxygpt_prompt_nonempty "SSH key path" "$default_path"
    selected_path="$(proxygpt_expand_user_path "$PROXYGPT_REPLY")"

    if [[ "$selected_path" != /* ]]; then
      proxygpt_warn "SSH key path must be absolute or start with ~/"
      default_path=""
      continue
    fi

    if [[ "$selected_path" == *.pub ]]; then
      proxygpt_warn "Enter the private key path, without the .pub suffix"
      default_path=""
      continue
    fi

    selected_path="${selected_path:A}"
    public_key="${selected_path}.pub"

    if [[ ! -e "$selected_path" && ! -e "$public_key" ]]; then
      proxygpt_config_set ssh_key_path "$selected_path"
      proxygpt_config_set ssh_key_action "generate"
      proxygpt_info "A new unencrypted Ed25519 key will be generated"
      return 0
    fi

    if proxygpt_ssh_key_is_unencrypted_ed25519 "$selected_path"; then
      proxygpt_config_set ssh_key_path "$selected_path"
      proxygpt_config_set ssh_key_action "reuse"
      proxygpt_success "Existing unencrypted Ed25519 key will be reused"
      return 0
    fi

    proxygpt_warn \
      "Existing path is not a complete unencrypted Ed25519 key pair; choose another path"
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
    proxygpt_die "SSH key path must be absolute: ${private_key}"
    return 1
  fi

  if [[ -e "$private_key" || -e "$public_key" ]]; then
    proxygpt_die "Refusing to overwrite an existing SSH key path: ${private_key}"
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
    proxygpt_die "Generated SSH key failed Ed25519/no-passphrase validation"
    return 1
  fi

  fingerprint="$(proxygpt_ssh_key_fingerprint "$public_key")"
  proxygpt_success "Generated Ed25519 tunnel key (${fingerprint})"
}

proxygpt_prepare_ssh_key() {
  local private_key="$(proxygpt_config_get ssh_key_path)"
  local public_key="${private_key}.pub"
  local expected_action="$(proxygpt_config_get ssh_key_action)"
  local fingerprint

  case "$expected_action" in
    reuse)
      if ! proxygpt_ssh_key_is_unencrypted_ed25519 "$private_key"; then
        proxygpt_die "SSH key changed after Preflight validation: ${private_key}"
        return 1
      fi

      chmod 600 "$private_key"
      chmod 644 "$public_key"
      fingerprint="$(proxygpt_ssh_key_fingerprint "$public_key")"
      proxygpt_success "Reusing Ed25519 tunnel key (${fingerprint})"
      ;;
    generate)
      if [[ -e "$private_key" || -e "$public_key" ]]; then
        proxygpt_die "SSH key path became occupied after Preflight: ${private_key}"
        return 1
      fi
      proxygpt_generate_ssh_key
      ;;
    *)
      proxygpt_die "SSH key action was not selected during Preflight"
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
    proxygpt_die "Unexpected local identity package path: ${package_dir}"
    return 1
  fi

  if ! cp "$public_key" "${package_dir}/tunnel-key.pub" ||
     ! cp "${PROXYGPT_ROOT}/templates/remote/server-common.sh" "$package_dir/" ||
     ! cp "${PROXYGPT_ROOT}/templates/remote/install-identity.sh" "$package_dir/"; then
    proxygpt_die "Could not assemble the local identity package: ${package_dir}"
    return 1
  fi

  {
    proxygpt_shell_assignment TUNNEL_USER "$(proxygpt_config_get tunnel_user)"
    proxygpt_shell_assignment SERVER_HOST "$(proxygpt_config_get server_host)"
  } > "${package_dir}/settings.sh" || {
    proxygpt_die "Could not write identity package settings: ${package_dir}"
    return 1
  }

  if ! chmod 600 "${package_dir}"/* ||
     ! chmod 700 "${package_dir}/install-identity.sh" ||
     ! bash -n "${package_dir}/install-identity.sh" "${package_dir}/server-common.sh" "${package_dir}/settings.sh"; then
    proxygpt_die "Identity package validation failed: ${package_dir}"
    return 1
  fi

  proxygpt_config_set local_identity_package_dir "$package_dir" || return 1
}

proxygpt_remove_local_identity_package() {
  local package_dir="$(proxygpt_config_get local_identity_package_dir)"

  [[ "$package_dir" =~ '^/tmp/proxygpt-identity-package\.[A-Za-z0-9]+$' ]] || return 1
  if ! rm -rf "$package_dir"; then
    proxygpt_die "Could not remove the local identity package: ${package_dir}"
    return 1
  fi
  proxygpt_config_set local_identity_package_dir "" || return 1
}
