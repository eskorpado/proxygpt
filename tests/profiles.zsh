#!/bin/zsh

emulate -LR zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

typeset -r PROJECT_ROOT="${0:A:h:h}"
typeset -r TEST_ROOT="$(mktemp -d /tmp/proxygpt-profiles-test.XXXXXXXX)"
typeset -r TEST_HOME="${TEST_ROOT}/home"

mkdir -p "$TEST_HOME"
HOME="$TEST_HOME"
PROXYGPT_ROOT="$PROJECT_ROOT"

source "${PROJECT_ROOT}/lib/ui.zsh"
source "${PROJECT_ROOT}/lib/profile.zsh"
source "${PROJECT_ROOT}/lib/config.zsh"
source "${PROJECT_ROOT}/lib/input.zsh"
source "${PROJECT_ROOT}/lib/runtime_install.zsh"
source "${PROJECT_ROOT}/lib/icon.zsh"
source "${PROJECT_ROOT}/lib/app_bundle.zsh"
source "${PROJECT_ROOT}/lib/ports.zsh"

typeset -A expected_product=(chatgpt ProxyGPT codex ProxyCodex claude ProxyClaude llm ProxyLLM)
typeset -A expected_cli=(chatgpt proxygpt codex proxycodex claude proxyclaude llm proxyllm)
typeset -A expected_prefix=(chatgpt chatgpt codex codex claude claude llm llm)
typeset profile_id product_name cli_name staged_app plist_value launcher

for profile_id in "${PROXYGPT_PROFILE_IDS[@]}"; do
  proxygpt_config_init
  proxygpt_configure_profile "$profile_id"
  product_name="${expected_product[$profile_id]}"
  cli_name="${expected_cli[$profile_id]}"

  [[ "$(proxygpt_config_get product_name)" == "$product_name" ]]
  [[ "$(proxygpt_config_get cli_name)" == "$cli_name" ]]
  [[ "$(proxygpt_config_get tunnel_user)" == "${expected_prefix[$profile_id]}-${USER}" ]]
  [[ "$(proxygpt_config_get ssh_key_path)" == "${HOME}/.ssh/${cli_name}_ed25519" ]]
  [[ "$(proxygpt_config_get runtime_command)" == "${HOME}/Library/Application Support/${product_name}/bin/${cli_name}" ]]
  [[ "$(proxygpt_config_get cli_link_path)" == "/usr/local/bin/${cli_name}" ]]
  [[ "$(proxygpt_config_get icon_source)" == "${PROJECT_ROOT}/assets/${product_name}.icns" ]]

  proxygpt_config_set app_path "${TEST_ROOT}/${profile_id}/${product_name}.app"
  staged_app="$(proxygpt_build_staged_app_bundle)"
  proxygpt_validate_app_bundle "$staged_app"
  plist_value="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "${staged_app}/Contents/Info.plist")"
  [[ "$plist_value" == "$product_name" ]]
  plist_value="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${staged_app}/Contents/Info.plist")"
  [[ "$plist_value" == "$(proxygpt_config_get bundle_id)" ]]
  launcher="$(<"${staged_app}/Contents/MacOS/launcher")"
  [[ "$launcher" == *"$(proxygpt_config_get runtime_command)"* ]]
done

proxygpt_config_init
proxygpt_configure_profile codex
proxygpt_local_port_is_in_use() { return 1; }
proxygpt_prompt_nonempty() { PROXYGPT_REPLY="$2"; }
proxygpt_prompt_local_proxy_port >/dev/null
typeset -i random_port="$(proxygpt_config_get local_proxy_port)"
(( random_port >= 49152 && random_port <= 65535 ))
[[ "$(proxygpt_config_get tunnel_control_socket)" == "${HOME}/.ssh/control/proxycodex-${random_port}.sock" ]]

print -r -- "PROFILES_OK"
