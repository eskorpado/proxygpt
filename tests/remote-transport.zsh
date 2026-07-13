#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -gA PROXYGPT_CONFIG=(
  admin_user root
  server_host example.test
  ssh_port 22
  ssh_host_key_policy accept-new
  admin_control_socket /tmp/proxygpt-admin.ABC123/master.sock
  remote_stage_dir /tmp/proxygpt.ABC123
)
typeset -g SSH_RESULT=0
typeset -g LAST_ERROR=""

proxygpt_config_get() { print -r -- "${PROXYGPT_CONFIG[$1]}"; }
proxygpt_config_set() { PROXYGPT_CONFIG[$1]="$2"; }
proxygpt_admin_master_require() { return 0; }
proxygpt_log() { return 0; }
proxygpt_success() { return 0; }
proxygpt_die() { LAST_ERROR="$1"; }
ssh() { return "$SSH_RESULT"; }

source "${PROJECT_ROOT}/lib/remote.zsh"

SSH_RESULT=37
typeset -i remote_status=0
if proxygpt_remote_execute_staged_script configure-server.sh; then
  remote_status=0
else
  remote_status=$?
fi
[[ "$remote_status" == 37 ]]
[[ "$LAST_ERROR" == *"кодом 37"* ]]
[[ "$LAST_ERROR" == *"/tmp/proxygpt.ABC123"* ]]
[[ "$(proxygpt_config_get remote_stage_dir)" == /tmp/proxygpt.ABC123 ]]

SSH_RESULT=0
LAST_ERROR=""
proxygpt_remote_execute_staged_script configure-server.sh
[[ -z "$(proxygpt_config_get remote_stage_dir)" ]]
[[ -z "$LAST_ERROR" ]]

print -r -- "REMOTE_TRANSPORT_OK"
