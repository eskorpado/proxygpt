#!/usr/bin/env bash

set -euo pipefail

readonly TUNNEL_USER="${1:-}"
[[ "$EUID" -eq 0 ]] || { printf 'Скрипт удаления должен выполняться от root\n' >&2; exit 1; }
[[ "$TUNNEL_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
  printf 'Недопустимое имя пользователя туннеля\n' >&2
  exit 1
}
[[ "$TUNNEL_USER" != root ]] || { printf 'Отказ от удаления root\n' >&2; exit 1; }

if ! id "$TUNNEL_USER" >/dev/null 2>&1; then
  printf 'Учётная запись пользователя туннеля уже отсутствует: %s\n' "$TUNNEL_USER"
  exit 0
fi

groups="$(id -nG "$TUNNEL_USER")"
shell="$(getent passwd "$TUNNEL_USER" | cut -d: -f7)"
password_state="$(passwd -S "$TUNNEL_USER" | awk '{print $2}')"
compatible=0
for group in $groups; do
  if [[ "$group" == codex-tunnel && "$shell" == /usr/sbin/nologin && "$password_state" == L ]]; then
    compatible=1
    break
  fi
done

if (( compatible == 0 )); then
  printf 'Профиль пользователя туннеля изменился:\n  пользователь: %s\n  группы: %s\n  shell: %s\n  пароль: %s\n' \
    "$TUNNEL_USER" "$groups" "$shell" "$password_state" >/dev/tty
  printf 'Всё равно удалить эту учётную запись и её домашний каталог?\n  1) Удалить\n  2) Прервать\nВыбор: ' >/dev/tty
  IFS= read -r choice </dev/tty
  [[ "$choice" == 1 ]] || exit 1
fi

userdel --remove "$TUNNEL_USER"
printf 'Удалены учётная запись пользователя туннеля и её домашний каталог: %s\n' "$TUNNEL_USER"
