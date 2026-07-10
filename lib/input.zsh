# Shared interactive input helpers. Results are returned in PROXYGPT_REPLY.

typeset -g PROXYGPT_REPLY=""

proxygpt_prompt_nonempty() {
  local label="${1:?prompt label is required}"
  local default_value="${2-}"
  local answer

  while true; do
    if [[ -n "$default_value" ]]; then
      print -nru2 -- "${label} [${default_value}]: "
    else
      print -nru2 -- "${label}: "
    fi

    if ! IFS= read -r answer; then
      proxygpt_die "Input ended while waiting for: ${label}"
      return 1
    fi

    if [[ -z "$answer" ]]; then
      answer="$default_value"
    fi

    if [[ -n "$answer" ]]; then
      PROXYGPT_REPLY="$answer"
      return 0
    fi

    proxygpt_warn "A value is required"
  done
}

proxygpt_prompt_menu() {
  local title="${1:?menu title is required}"
  shift
  local -a options=("$@")
  local answer
  local index

  if (( ${#options} == 0 )); then
    proxygpt_die "Menu has no options: ${title}"
    return 1
  fi

  while true; do
    print -r -- "$title"
    for (( index = 1; index <= ${#options}; index++ )); do
      print -r -- "  ${index}) ${options[index]}"
    done
    print -nru2 -- "Select [1]: "

    if ! IFS= read -r answer; then
      proxygpt_die "Input ended while waiting for: ${title}"
      return 1
    fi

    answer="${answer:-1}"
    if [[ "$answer" == <-> ]] && (( answer >= 1 && answer <= ${#options} )); then
      PROXYGPT_REPLY="$answer"
      return 0
    fi

    proxygpt_warn "Enter a number from 1 to ${#options}"
  done
}

proxygpt_prompt_yes_no() {
  local label="${1:?prompt label is required}"
  local default_answer="${2:-yes}"
  local hint
  local answer

  if [[ "$default_answer" == "yes" ]]; then
    hint="Y/n"
  elif [[ "$default_answer" == "no" ]]; then
    hint="y/N"
  else
    proxygpt_die "Invalid yes/no default: ${default_answer}"
    return 1
  fi

  while true; do
    print -nru2 -- "${label} [${hint}]: "
    if ! IFS= read -r answer; then
      proxygpt_die "Input ended while waiting for: ${label}"
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
        proxygpt_warn "Enter yes or no"
        ;;
    esac
  done
}
