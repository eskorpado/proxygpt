# Реестр этапов и обработка аргументов верхнего уровня.

typeset -ga PROXYGPT_STEP_FUNCTIONS=(
  proxygpt_step_preflight
  proxygpt_step_server
  proxygpt_step_identity
  proxygpt_step_tunnel
  proxygpt_step_app
  proxygpt_step_integration
)

typeset -ga PROXYGPT_STEP_LABELS=(
  Проверка
  Сервер
  Ключи
  Туннель
  Приложение
  Интеграция
)

proxygpt_usage() {
  print -r -- "Установщик ProxyGPT ${PROXYGPT_VERSION}"
  print
  print -r -- "Использование: ${PROXYGPT_PROGRAM} [--help | --list-steps | --check]"
  print
  print -r -- "Без аргументов запускается интерактивная установка."
  print -r -- "  --help        Показать эту справку"
  print -r -- "  --list-steps  Показать этапы установки"
  print -r -- "  --check       Проверить загрузку функций всех этапов"
}

proxygpt_list_steps() {
  local index
  local total="${#PROXYGPT_STEP_LABELS}"

  for (( index = 1; index <= total; index++ )); do
    print -r -- "[${index}/${total}] ${PROXYGPT_STEP_LABELS[index]}"
  done
}

proxygpt_validate_steps() {
  local step

  for step in "${PROXYGPT_STEP_FUNCTIONS[@]}"; do
    if (( ! ${+functions[$step]} )); then
      proxygpt_die "Не загружена обязательная функция этапа: ${step}"
    fi
  done

  proxygpt_success "Загружены функции всех этапов: ${#PROXYGPT_STEP_FUNCTIONS}"
}

proxygpt_run_steps() {
  local index
  local step
  local total="${#PROXYGPT_STEP_FUNCTIONS}"

  proxygpt_validate_steps

  for (( index = 1; index <= total; index++ )); do
    step="${PROXYGPT_STEP_FUNCTIONS[index]}"
    PROXYGPT_CURRENT_PHASE="${PROXYGPT_STEP_LABELS[index]}"
    proxygpt_phase "$index" "$total" "${PROXYGPT_STEP_LABELS[index]}"
    "$step"
  done
}

proxygpt_main() {
  proxygpt_config_init

  if (( $# > 1 )); then
    proxygpt_usage >&2
    return 64
  fi

  case "${1:-}" in
    "")
      proxygpt_run_steps
      ;;
    --help|-h)
      proxygpt_usage
      ;;
    --list-steps)
      proxygpt_list_steps
      ;;
    --check)
      proxygpt_validate_steps
      ;;
    *)
      proxygpt_error "Неизвестный параметр: $1"
      proxygpt_usage >&2
      return 64
      ;;
  esac
}
