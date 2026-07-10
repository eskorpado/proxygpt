#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-runtime-test.XXXXXXXX)"
typeset -r EVENTS_FILE="${TEST_ROOT}/events.log"
typeset -r BIN_DIR="${TEST_ROOT}/bin"
typeset -r CONFIG_DIR="${TEST_ROOT}/config"
typeset -r TARGET_COMMAND="${BIN_DIR}/fake-target"
typeset -i runtime_exit

mkdir "$BIN_DIR" "$CONFIG_DIR"
cp "${PROJECT_ROOT}/templates/runtime/proxygpt" "${BIN_DIR}/proxygpt"
cp "${PROJECT_ROOT}/tests/fixtures/fake-tunnel" "${BIN_DIR}/proxygpt-tunnel"
cp "${PROJECT_ROOT}/tests/fixtures/fake-target" "$TARGET_COMMAND"
chmod 755 "${BIN_DIR}/proxygpt" "${BIN_DIR}/proxygpt-tunnel" "$TARGET_COMMAND"

{
  print -r -- 'TARGET_APP_NAME="Fake Target"'
  print -r -- "TARGET_APP_EXECUTABLE=${(qqq)TARGET_COMMAND}"
  print -r -- 'LOCAL_PORT="43128"'
} > "${CONFIG_DIR}/proxygpt.conf"

if PROXYGPT_TEST_EVENTS="$EVENTS_FILE" \
   PROXYGPT_TEST_TARGET_EXIT=23 \
   "${BIN_DIR}/proxygpt"; then
  runtime_exit=0
else
  runtime_exit=$?
fi

if (( runtime_exit != 23 )); then
  print -ru2 -- "Expected runtime exit 23, got ${runtime_exit}"
  exit 1
fi

typeset -a events=("${(@f)$(<"$EVENTS_FILE")}")
if [[ "${(j: :)events}" != "start target stop" ]]; then
  print -ru2 -- "Unexpected lifecycle: ${(j: :)events}"
  exit 1
fi

: > "$EVENTS_FILE"

if PROXYGPT_TEST_EVENTS="$EVENTS_FILE" \
   PROXYGPT_TEST_TARGET_EXIT=23 \
   PROXYGPT_TEST_STOP_EXIT=9 \
   "${BIN_DIR}/proxygpt"; then
  runtime_exit=0
else
  runtime_exit=$?
fi

if (( runtime_exit != 23 )); then
  print -ru2 -- "Stop failure replaced target exit code: ${runtime_exit}"
  exit 1
fi

events=("${(@f)$(<"$EVENTS_FILE")}")
if [[ "${(j: :)events}" != "start target stop" ]]; then
  print -ru2 -- "Unexpected stop-failure lifecycle: ${(j: :)events}"
  exit 1
fi

print -r -- "RUNTIME_LIFECYCLE_OK"
