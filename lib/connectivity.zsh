# Обязательные проверки локального процесса прослушивания и адресов через прокси.

proxygpt_local_proxy_url() {
  local local_port="$(proxygpt_config_get local_proxy_port)"

  if [[ "$local_port" != <-> ]] || (( local_port < 1 || local_port > 65535 )); then
    proxygpt_die "Недопустимый локальный порт прокси: ${local_port}"
    return 1
  fi

  print -r -- "http://127.0.0.1:${local_port}"
}

proxygpt_test_local_proxy_listener() {
  local local_port="$(proxygpt_config_get local_proxy_port)"

  if ! nc -z -w 3 127.0.0.1 "$local_port"; then
    proxygpt_die "Локальный процесс прослушивания прокси недоступен на 127.0.0.1:${local_port}"
    return 1
  fi

  proxygpt_success "Локальный процесс прослушивания прокси доступен на 127.0.0.1:${local_port}"
}

proxygpt_http_status_is_reachable() {
  local http_code="${1:?требуется HTTP-статус}"

  [[ "$http_code" == <-> ]] || return 1
  (( http_code >= 200 && http_code <= 499 && http_code != 407 ))
}

proxygpt_test_proxy_endpoint() {
  local label="${1:?требуется название проверяемого адреса}"
  local url="${2:?требуется URL проверяемого адреса}"
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
    proxygpt_die "Запрос через прокси завершился ошибкой для ${label}"
    return 1
  fi

  if ! proxygpt_http_status_is_reachable "$http_code"; then
    proxygpt_die "Неожиданный HTTP-статус ${http_code} от ${label} через прокси"
    return 1
  fi

  proxygpt_success "${label} доступен через прокси (HTTP ${http_code})"
}

proxygpt_test_required_proxy_endpoints() {
  proxygpt_test_proxy_endpoint \
    "api.openai.com" \
    "https://api.openai.com/v1/models"
  proxygpt_test_proxy_endpoint \
    "chatgpt.com" \
    "https://chatgpt.com/"
}
