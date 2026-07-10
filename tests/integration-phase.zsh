#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-integration-phase-test.XXXXXXXX)"
typeset -r EVENTS_FILE="${TEST_ROOT}/events.log"
typeset -r BIN_DIR="${TEST_ROOT}/bin"

mkdir "$BIN_DIR"
cp "${PROJECT_ROOT}/tests/fixtures/fake-tunnel" "${BIN_DIR}/proxygpt-tunnel"
chmod 755 "${BIN_DIR}/proxygpt-tunnel"

typeset -gA PROXYGPT_CONFIG=(
  runtime_command "${BIN_DIR}/proxygpt"
  app_path "${TEST_ROOT}/ProxyGPT.app"
  cli_link_path "${TEST_ROOT}/proxygpt"
)
typeset -ga checks=()

proxygpt_config_get() { print -r -- "${PROXYGPT_CONFIG[$1]}"; }
proxygpt_install_cli_link() { checks+=(cli); }
proxygpt_test_local_proxy_listener() { checks+=(listener); return "${LISTENER_STATUS:-0}"; }
proxygpt_test_required_proxy_endpoints() { checks+=(endpoints); return "${ENDPOINT_STATUS:-0}"; }
proxygpt_success() { return 0; }
proxygpt_warn() { return 0; }

source "${PROJECT_ROOT}/steps/06-integration.zsh"

PROXYGPT_TEST_EVENTS="$EVENTS_FILE" proxygpt_step_integration >/dev/null
typeset -a events=("${(@f)$(<"$EVENTS_FILE")}")
[[ "${(j: :)events}" == "start stop" ]] || exit 1
[[ "${(j: :)checks}" == "cli listener endpoints" ]] || exit 1

: > "$EVENTS_FILE"
checks=()
typeset -i phase_status
if PROXYGPT_TEST_EVENTS="$EVENTS_FILE" ENDPOINT_STATUS=19 proxygpt_step_integration >/dev/null; then
  phase_status=0
else
  phase_status=$?
fi
[[ "$phase_status" == 19 ]] || {
  print -ru2 -- "Expected endpoint status 19, got ${phase_status}"
  exit 1
}
events=("${(@f)$(<"$EVENTS_FILE")}")
[[ "${(j: :)events}" == "start stop" ]] || exit 1

print -r -- "INTEGRATION_PHASE_OK"
