# Required local listener and proxied endpoint checks.

proxygpt_local_proxy_url() {
  local local_port="$(proxygpt_config_get local_proxy_port)"

  if [[ "$local_port" != <-> ]] || (( local_port < 1 || local_port > 65535 )); then
    proxygpt_die "Invalid local proxy port: ${local_port}"
    return 1
  fi

  print -r -- "http://127.0.0.1:${local_port}"
}

proxygpt_test_local_proxy_listener() {
  local local_port="$(proxygpt_config_get local_proxy_port)"

  if ! nc -z -w 3 127.0.0.1 "$local_port"; then
    proxygpt_die "Local proxy listener is unavailable on 127.0.0.1:${local_port}"
    return 1
  fi

  proxygpt_success "Local proxy listener is reachable on 127.0.0.1:${local_port}"
}

proxygpt_http_status_is_reachable() {
  local http_code="${1:?HTTP status is required}"

  [[ "$http_code" == <-> ]] || return 1
  (( http_code >= 200 && http_code <= 499 && http_code != 407 ))
}

proxygpt_test_proxy_endpoint() {
  local label="${1:?endpoint label is required}"
  local url="${2:?endpoint URL is required}"
  local proxy_url="$(proxygpt_local_proxy_url)"
  local http_code

  if ! http_code="$(curl \
    --proxy "$proxy_url" \
    --noproxy "" \
    --connect-timeout 10 \
    --max-time 30 \
    --silent \
    --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    "$url")"; then
    proxygpt_die "Proxy request failed for ${label}"
    return 1
  fi

  if ! proxygpt_http_status_is_reachable "$http_code"; then
    proxygpt_die "Unexpected HTTP status ${http_code} from ${label} through the proxy"
    return 1
  fi

  proxygpt_success "${label} is reachable through the proxy (HTTP ${http_code})"
}

proxygpt_test_required_proxy_endpoints() {
  proxygpt_test_proxy_endpoint \
    "api.openai.com" \
    "https://api.openai.com/v1/models"
  proxygpt_test_proxy_endpoint \
    "chatgpt.com" \
    "https://chatgpt.com/"
}
