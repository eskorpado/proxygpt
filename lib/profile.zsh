# Fixed output profile metadata shared by installer and uninstaller.

typeset -ga PROXYGPT_PROFILE_IDS=(chatgpt codex claude llm)

proxygpt_profile_field() {
  local profile_id="${1:?profile id is required}"
  local field="${2:?profile field is required}"

  case "${profile_id}:${field}" in
    chatgpt:product) print -r -- "ProxyGPT" ;;
    chatgpt:cli) print -r -- "proxygpt" ;;
    chatgpt:bundle_id) print -r -- "com.local.proxygpt" ;;
    chatgpt:tunnel_prefix) print -r -- "chatgpt" ;;
    codex:product) print -r -- "ProxyCodex" ;;
    codex:cli) print -r -- "proxycodex" ;;
    codex:bundle_id) print -r -- "com.local.proxycodex" ;;
    codex:tunnel_prefix) print -r -- "codex" ;;
    claude:product) print -r -- "ProxyClaude" ;;
    claude:cli) print -r -- "proxyclaude" ;;
    claude:bundle_id) print -r -- "com.local.proxyclaude" ;;
    claude:tunnel_prefix) print -r -- "claude" ;;
    llm:product) print -r -- "ProxyLLM" ;;
    llm:cli) print -r -- "proxyllm" ;;
    llm:bundle_id) print -r -- "com.local.proxyllm" ;;
    llm:tunnel_prefix) print -r -- "llm" ;;
    *) return 1 ;;
  esac
}

proxygpt_profile_is_valid() {
  proxygpt_profile_field "$1" product >/dev/null 2>&1
}
