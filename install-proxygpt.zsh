#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -gr PROXYGPT_ROOT="${0:A:h}"
typeset -gr PROXYGPT_PROGRAM="${0:t}"
typeset -gr PROXYGPT_VERSION="0.1.0-dev"

source "${PROXYGPT_ROOT}/lib/ui.zsh"
source "${PROXYGPT_ROOT}/lib/input.zsh"
source "${PROXYGPT_ROOT}/lib/config.zsh"
source "${PROXYGPT_ROOT}/lib/logging.zsh"
source "${PROXYGPT_ROOT}/lib/ports.zsh"
source "${PROXYGPT_ROOT}/lib/app.zsh"
source "${PROXYGPT_ROOT}/lib/cli.zsh"
source "${PROXYGPT_ROOT}/lib/remote.zsh"
source "${PROXYGPT_ROOT}/lib/server.zsh"
source "${PROXYGPT_ROOT}/lib/connectivity.zsh"
source "${PROXYGPT_ROOT}/lib/identity.zsh"
source "${PROXYGPT_ROOT}/lib/icon.zsh"
source "${PROXYGPT_ROOT}/lib/app_bundle.zsh"
source "${PROXYGPT_ROOT}/lib/runtime_install.zsh"
source "${PROXYGPT_ROOT}/lib/orchestrator.zsh"

source "${PROXYGPT_ROOT}/steps/01-preflight.zsh"
source "${PROXYGPT_ROOT}/steps/02-server.zsh"
source "${PROXYGPT_ROOT}/steps/03-identity.zsh"
source "${PROXYGPT_ROOT}/steps/04-tunnel.zsh"
source "${PROXYGPT_ROOT}/steps/05-app.zsh"
source "${PROXYGPT_ROOT}/steps/06-integration.zsh"

proxygpt_main "$@"
