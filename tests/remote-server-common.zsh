#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r COMMON_SCRIPT="${PROJECT_ROOT}/templates/remote/server-common.sh"

force_command_is_compatible() {
  bash -c 'source "$1"; proxygpt_force_command_is_compatible "$2"' \
    proxygpt-test "$COMMON_SCRIPT" "$1"
}

force_command_is_compatible none
force_command_is_compatible /usr/sbin/nologin
! force_command_is_compatible /bin/bash
! force_command_is_compatible internal-sftp
! force_command_is_compatible ""

print -r -- "REMOTE_SERVER_COMMON_OK"
