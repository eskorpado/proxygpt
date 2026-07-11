#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -ga events=()

proxygpt_install_app_bundle() { events+=(install); }
proxygpt_register_app_bundle() { events+=(register); }
proxygpt_success() { events+=(success); }

source "${PROJECT_ROOT}/steps/05-app.zsh"
proxygpt_step_app

[[ "${(j: :)events}" == "install register success" ]] || {
  print -ru2 -- "Неожиданный жизненный цикл этапа приложения: ${(j: :)events}"
  exit 1
}

print -r -- "APP_PHASE_OK"
