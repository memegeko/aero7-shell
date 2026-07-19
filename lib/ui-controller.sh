#!/usr/bin/env bash

if [[ -n "${AERO7_UI_CONTROLLER_LOADED:-}" ]]; then
  return 0
fi
AERO7_UI_CONTROLLER_LOADED=1

aero7_stdin_tty() {
  [[ -t 0 ]] || [[ -r /dev/tty ]]
}

aero7_stdout_tty() {
  [[ -t 1 ]] || [[ -w /dev/tty ]]
}

aero7_terminal_size() {
  local rows cols size
  rows="${LINES:-}"
  cols="${COLUMNS:-}"
  if [[ -z "$rows" || -z "$cols" ]]; then
    size="$(stty size 2>/dev/null || true)"
    if [[ -n "$size" ]] && read -r rows cols <<<"$size"; then
      :
    else
      rows=0
      cols=0
    fi
  fi
  printf '%s %s\n' "${rows:-0}" "${cols:-0}"
}

aero7_python_path() {
  if command -v python >/dev/null 2>&1; then
    command -v python
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return 0
  fi
  return 1
}

aero7_curses_import_result() {
  local python_bin="${1:-}"
  [[ -n "$python_bin" ]] || {
    printf 'not-tested\n'
    return 1
  }
  "$python_bin" - <<'PY' >/dev/null 2>&1
import curses
PY
}

aero7_tui_terminal_reason() {
  local rows cols
  read -r rows cols < <(aero7_terminal_size)

  aero7_stdin_tty || {
    printf 'stdin is not a TTY\n'
    return 1
  }
  aero7_stdout_tty || {
    printf 'stdout is not a TTY\n'
    return 1
  }
  [[ "${TERM:-}" != "dumb" && -n "${TERM:-}" ]] || {
    printf 'TERM=dumb\n'
    return 1
  }
  [[ "${CI:-}" != "true" ]] || {
    printf 'CI=true\n'
    return 1
  }
  [[ "${AERO7_DEBUG:-0}" != "1" ]] || {
    printf 'debug mode requested\n'
    return 1
  }
  [[ "${AERO7_PLAIN:-0}" != "1" ]] || {
    printf 'plain mode requested\n'
    return 1
  }
  [[ "$cols" -ge 80 && "$rows" -ge 24 ]] || {
    printf 'terminal is smaller than 80x24\n'
    return 1
  }
  printf 'available\n'
}

aero7_tui_runtime_reason() {
  local python_bin
  python_bin="$(aero7_python_path || true)"
  [[ -n "$python_bin" ]] || {
    printf 'Python is not installed\n'
    return 1
  }
  if ! aero7_curses_import_result "$python_bin"; then
    printf 'Python curses could not initialize\n'
    return 1
  fi
  printf 'available\n'
}

aero7_select_ui_mode() {
  local reason
  reason="$(aero7_tui_terminal_reason || true)"
  if [[ "$reason" == "available" ]]; then
    printf 'tui\n'
  else
    printf 'plain:%s\n' "$reason"
  fi
}

aero7_ui_diagnostics() {
  local rows cols python_bin curses_result selected reason runtime_reason stdin_tty stdout_tty
  read -r rows cols < <(aero7_terminal_size)
  python_bin="$(aero7_python_path || true)"
  if [[ -n "$python_bin" ]] && aero7_curses_import_result "$python_bin"; then
    curses_result="ok"
  elif [[ -n "$python_bin" ]]; then
    curses_result="failed"
  else
    curses_result="not-tested"
  fi
  selected="$(aero7_select_ui_mode)"
  if [[ "$selected" == tui ]]; then
    reason="none"
  else
    reason="${selected#plain:}"
  fi
  runtime_reason="$(aero7_tui_runtime_reason || true)"
  stdin_tty=no
  stdout_tty=no
  aero7_stdin_tty && stdin_tty=yes
  aero7_stdout_tty && stdout_tty=yes

  printf 'stdin_tty=%s\n' "$stdin_tty"
  printf 'stdout_tty=%s\n' "$stdout_tty"
  printf 'term=%s\n' "${TERM:-}"
  printf 'columns=%s\n' "$cols"
  printf 'rows=%s\n' "$rows"
  printf 'python=%s\n' "${python_bin:-missing}"
  printf 'curses_import=%s\n' "$curses_result"
  printf 'selected_ui_mode=%s\n' "${selected%%:*}"
  printf 'fallback_reason=%s\n' "$reason"
  printf 'runtime_reason=%s\n' "$runtime_reason"
}

aero7_tui_bootstrap_python_if_needed() {
  if aero7_python_path >/dev/null 2>&1; then
    return 0
  fi
  printf 'Aero7-shell Setup\n'
  printf 'Preparing the graphical terminal installer...\n'
  aero7_require_arch_or_dry_run
  aero7_sudo_keepalive_start
  aero7_pacman_install_needed python
  aero7_sudo_keepalive_stop
}

aero7_launch_tui() {
  local python_bin reason
  reason="$(aero7_tui_runtime_reason || true)"
  if [[ "$reason" != "available" ]]; then
    printf 'TUI unavailable: %s\n' "$reason" >&2
    return 1
  fi
  python_bin="$(aero7_python_path || true)"
  "$python_bin" "$AERO7_PROJECT_ROOT/ui/aero7_setup.py" "$@"
}
