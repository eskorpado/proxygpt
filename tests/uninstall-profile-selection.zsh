#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-uninstall-profile-test.XXXXXXXX)"
typeset -r TEST_HOME="${TEST_ROOT}/home"

mkdir -p "$TEST_HOME"
HOME="$TEST_HOME"
PROXYGPT_ROOT="$PROJECT_ROOT"

source "${PROJECT_ROOT}/lib/ui.zsh"
source "${PROJECT_ROOT}/lib/profile.zsh"
source "${PROJECT_ROOT}/lib/config.zsh"
source "${PROJECT_ROOT}/lib/runtime_install.zsh"

proxygpt_config_init
proxygpt_configure_profile claude
proxygpt_config_set server_host proxy.example.test
proxygpt_config_set admin_user admin
proxygpt_config_set ssh_port 22
proxygpt_config_set local_proxy_port 55001
proxygpt_config_set tunnel_control_socket "${HOME}/.ssh/control/proxyclaude-55001.sock"
proxygpt_write_install_manifest >/dev/null

typeset -i exit_code=0
printf '\n1\n1\n2\n' | HOME="$HOME" "${PROJECT_ROOT}/uninstall.sh" >/dev/null 2>&1 || exit_code=$?
[[ "$exit_code" == 130 ]]
[[ -f "${HOME}/Library/Application Support/ProxyClaude/config/install-manifest.conf" ]]

print -r -- "UNINSTALL_PROFILE_SELECTION_OK"
