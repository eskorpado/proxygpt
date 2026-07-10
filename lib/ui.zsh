# Shared terminal output helpers.

proxygpt_info() {
  print -r -- "  $*"
  if (( ${+functions[proxygpt_log]} )); then
    proxygpt_log INFO "$*"
  fi
}

proxygpt_success() {
  print -r -- "  ✓ $*"
  if (( ${+functions[proxygpt_log]} )); then
    proxygpt_log SUCCESS "$*"
  fi
}

proxygpt_warn() {
  print -ru2 -- "  ! $*"
  if (( ${+functions[proxygpt_log]} )); then
    proxygpt_log WARN "$*"
  fi
}

proxygpt_error() {
  print -ru2 -- "  ✗ $*"
  if (( ${+functions[proxygpt_log]} )); then
    proxygpt_log ERROR "$*"
  fi
}

proxygpt_die() {
  proxygpt_error "$*"
  return 1
}

proxygpt_phase() {
  local current="$1"
  local total="$2"
  local label="$3"

  print
  print -r -- "[${current}/${total}] ${label}"
  if (( ${+functions[proxygpt_log]} )); then
    proxygpt_log PHASE "[${current}/${total}] ${label}"
  fi
}
