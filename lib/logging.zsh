# Plain-text installer logging. Logging remains inactive until initialization.

typeset -g PROXYGPT_LOG_FILE=""
typeset -g PROXYGPT_CURRENT_PHASE="Bootstrap"

proxygpt_log() {
  local level="${1:?log level is required}"
  shift
  local message="$*"
  local timestamp

  [[ -n "${PROXYGPT_LOG_FILE:-}" ]] || return 0

  timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  message="${message//$'\n'/ }"

  print -r -- \
    "[${timestamp}] [${level}] [${PROXYGPT_CURRENT_PHASE:-Bootstrap}] ${message}" \
    >> "$PROXYGPT_LOG_FILE"
}

proxygpt_log_init() {
  local logs_dir="$(proxygpt_config_get logs_dir)"
  local log_name="install-$(date '+%Y%m%d-%H%M%S')-$$.log"

  mkdir -p "$logs_dir"
  chmod 700 "$logs_dir"

  PROXYGPT_LOG_FILE="${logs_dir}/${log_name}"
  (umask 077; : > "$PROXYGPT_LOG_FILE")
  proxygpt_config_set installer_log "$PROXYGPT_LOG_FILE"

  proxygpt_log INFO "Installer log initialized"
}
