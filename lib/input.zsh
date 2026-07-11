# Общие функции интерактивного ввода. Результат возвращается в PROXYGPT_REPLY.

typeset -g PROXYGPT_REPLY=""

proxygpt_prompt_nonempty() {
  local label="${1:?требуется название запроса}"
  local default_value="${2-}"
  local answer

  while true; do
    if [[ -n "$default_value" ]]; then
      print -nru2 -- "${label} [${default_value}]: "
    else
      print -nru2 -- "${label}: "
    fi

    if ! IFS= read -r answer; then
      proxygpt_die "Ввод завершился во время ожидания значения: ${label}"
      return 1
    fi

    if [[ -z "$answer" ]]; then
      answer="$default_value"
    fi

    if [[ -n "$answer" ]]; then
      PROXYGPT_REPLY="$answer"
      return 0
    fi

    proxygpt_warn "Необходимо ввести значение"
  done
}

proxygpt_prompt_menu() {
  local title="${1:?требуется заголовок меню}"
  shift
  local -a options=("$@")
  local answer
  local index

  if (( ${#options} == 0 )); then
    proxygpt_die "В меню нет вариантов: ${title}"
    return 1
  fi

  while true; do
    print -r -- "$title"
    for (( index = 1; index <= ${#options}; index++ )); do
      print -r -- "  ${index}) ${options[index]}"
    done
    print -nru2 -- "Выбор [1]: "

    if ! IFS= read -r answer; then
      proxygpt_die "Ввод завершился во время ожидания выбора: ${title}"
      return 1
    fi

    answer="${answer:-1}"
    if [[ "$answer" == <-> ]] && (( answer >= 1 && answer <= ${#options} )); then
      PROXYGPT_REPLY="$answer"
      return 0
    fi

    proxygpt_warn "Введите число от 1 до ${#options}"
  done
}

proxygpt_prompt_yes_no() {
  local label="${1:?требуется название запроса}"
  local default_answer="${2:-yes}"
  local hint
  local answer

  if [[ "$default_answer" == "yes" ]]; then
    hint="Y/n"
  elif [[ "$default_answer" == "no" ]]; then
    hint="y/N"
  else
    proxygpt_die "Недопустимое значение по умолчанию для да/нет: ${default_answer}"
    return 1
  fi

  while true; do
    print -nru2 -- "${label} [${hint}]: "
    if ! IFS= read -r answer; then
      proxygpt_die "Ввод завершился во время ожидания ответа: ${label}"
      return 1
    fi

    answer="${answer:l}"
    if [[ -z "$answer" ]]; then
      PROXYGPT_REPLY="$default_answer"
      return 0
    fi

    case "$answer" in
      y|yes)
        PROXYGPT_REPLY="yes"
        return 0
        ;;
      n|no)
        PROXYGPT_REPLY="no"
        return 0
        ;;
      *)
        proxygpt_warn "Введите y/yes или n/no"
        ;;
    esac
  done
}
