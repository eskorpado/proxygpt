#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-target-profile-test.XXXXXXXX)"
typeset -r TEST_HOME="${TEST_ROOT}/home"
typeset -r CLAUDE_APP="${TEST_HOME}/Applications/Claude.app"
typeset -r CUSTOM_APP="${TEST_ROOT}/Custom.app"

HOME="$TEST_HOME"
PROXYGPT_ROOT="$PROJECT_ROOT"

source "${PROJECT_ROOT}/lib/ui.zsh"
source "${PROJECT_ROOT}/lib/input.zsh"
source "${PROJECT_ROOT}/lib/profile.zsh"
source "${PROJECT_ROOT}/lib/config.zsh"
source "${PROJECT_ROOT}/lib/app.zsh"

for bundle in "$CLAUDE_APP" "$CUSTOM_APP"; do
  mkdir -p "${bundle}/Contents/MacOS"
  cp "${PROJECT_ROOT}/templates/app/Info.plist" "${bundle}/Contents/Info.plist"
  cp /usr/bin/true "${bundle}/Contents/MacOS/launcher"
  chmod 755 "${bundle}/Contents/MacOS/launcher"
done

proxygpt_config_init
proxygpt_configure_target_app "$CLAUDE_APP" claude
[[ "$(proxygpt_config_get profile_id)" == claude ]]
[[ "$(proxygpt_config_get product_name)" == ProxyClaude ]]
[[ "$(proxygpt_config_get cli_name)" == proxyclaude ]]

proxygpt_config_init
proxygpt_configure_target_app "$CUSTOM_APP" llm
[[ "$(proxygpt_config_get profile_id)" == llm ]]
[[ "$(proxygpt_config_get product_name)" == ProxyLLM ]]
[[ "$(proxygpt_config_get cli_name)" == proxyllm ]]

print -r -- "TARGET_PROFILE_SELECTION_OK"
