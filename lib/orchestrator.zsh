# Phase registry and top-level command handling.

typeset -ga PROXYGPT_STEP_FUNCTIONS=(
  proxygpt_step_preflight
  proxygpt_step_server
  proxygpt_step_identity
  proxygpt_step_tunnel
  proxygpt_step_app
  proxygpt_step_integration
)

typeset -ga PROXYGPT_STEP_LABELS=(
  Preflight
  Server
  Identity
  Tunnel
  App
  Integration
)

proxygpt_usage() {
  print -r -- "ProxyGPT installer ${PROXYGPT_VERSION}"
  print
  print -r -- "Usage: ${PROXYGPT_PROGRAM} [--help | --list-steps | --check]"
  print
  print -r -- "Without arguments, runs the interactive installer."
  print -r -- "  --help        Show this help"
  print -r -- "  --list-steps  Print the installer phases"
  print -r -- "  --check       Validate that all phase functions are loaded"
}

proxygpt_list_steps() {
  local index
  local total="${#PROXYGPT_STEP_LABELS}"

  for (( index = 1; index <= total; index++ )); do
    print -r -- "[${index}/${total}] ${PROXYGPT_STEP_LABELS[index]}"
  done
}

proxygpt_validate_steps() {
  local step

  for step in "${PROXYGPT_STEP_FUNCTIONS[@]}"; do
    if (( ! ${+functions[$step]} )); then
      proxygpt_die "Required phase function is not loaded: ${step}"
    fi
  done

  proxygpt_success "All ${#PROXYGPT_STEP_FUNCTIONS} phase functions are loaded"
}

proxygpt_run_steps() {
  local index
  local step
  local total="${#PROXYGPT_STEP_FUNCTIONS}"

  proxygpt_validate_steps

  for (( index = 1; index <= total; index++ )); do
    step="${PROXYGPT_STEP_FUNCTIONS[index]}"
    PROXYGPT_CURRENT_PHASE="${PROXYGPT_STEP_LABELS[index]}"
    proxygpt_phase "$index" "$total" "${PROXYGPT_STEP_LABELS[index]}"
    "$step"
  done
}

proxygpt_main() {
  proxygpt_config_init

  if (( $# > 1 )); then
    proxygpt_usage >&2
    return 64
  fi

  case "${1:-}" in
    "")
      proxygpt_run_steps
      ;;
    --help|-h)
      proxygpt_usage
      ;;
    --list-steps)
      proxygpt_list_steps
      ;;
    --check)
      proxygpt_validate_steps
      ;;
    *)
      proxygpt_error "Unknown option: $1"
      proxygpt_usage >&2
      return 64
      ;;
  esac
}
