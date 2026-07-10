#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-uninstall-local-test.XXXXXXXX)"
typeset -r TEST_ITEM="${TEST_ROOT}/ProxyGPT.app"

mkdir -p "${TEST_ITEM}/Contents"
source "${PROJECT_ROOT}/lib/uninstall_local.zsh"

typeset -r ORIGINAL_PATH="$PATH"
proxygpt_remove_configured_path "$TEST_ITEM"

[[ ! -e "$TEST_ITEM" ]]
[[ "$PATH" == "$ORIGINAL_PATH" ]]
command mkdir "${TEST_ROOT}/still-works"

print -r -- "UNINSTALL_LOCAL_OK"
