#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-tunnel-phase-test.XXXXXXXX)"
typeset -r EVENTS_FILE="${TEST_ROOT}/events.log"
typeset -r BIN_DIR="${TEST_ROOT}/bin"

mkdir "$BIN_DIR"
cp "${PROJECT_ROOT}/tests/fixtures/fake-tunnel" "${BIN_DIR}/proxygpt-tunnel"
chmod 755 "${BIN_DIR}/proxygpt-tunnel"

typeset -gA PROXYGPT_CONFIG=(runtime_command "${BIN_DIR}/proxygpt")

proxygpt_config_get() { print -r -- "${PROXYGPT_CONFIG[$1]}"; }
proxygpt_install_runtime_files() { return 0; }
proxygpt_test_local_proxy_listener() { return 0; }
proxygpt_success() { return 0; }
proxygpt_warn() { return 0; }

source "${PROJECT_ROOT}/steps/04-tunnel.zsh"

PROXYGPT_TEST_EVENTS="$EVENTS_FILE" proxygpt_step_tunnel
typeset -a events=("${(@f)$(<"$EVENTS_FILE")}")
[[ "${(j: :)events}" == "start stop" ]] || {
  print -ru2 -- "Неожиданный жизненный цикл быстрой проверки туннеля: ${(j: :)events}"
  exit 1
}

: > "$EVENTS_FILE"
proxygpt_test_local_proxy_listener() { return 17; }
typeset -i phase_status
if PROXYGPT_TEST_EVENTS="$EVENTS_FILE" proxygpt_step_tunnel; then
  phase_status=0
else
  phase_status=$?
fi
[[ "$phase_status" == 17 ]] || {
  print -ru2 -- "Ожидался код процесса прослушивания 17, получен ${phase_status}"
  exit 1
}
events=("${(@f)$(<"$EVENTS_FILE")}")
[[ "${(j: :)events}" == "start stop" ]] || {
  print -ru2 -- "После ошибки туннель не был остановлен: ${(j: :)events}"
  exit 1
}

print -r -- "TUNNEL_PHASE_OK"
