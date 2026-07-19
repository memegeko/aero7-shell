#!/usr/bin/env bash

if [[ -n "${AERO7_PROMPTS_LOADED:-}" ]]; then
  return 0
fi
AERO7_PROMPTS_LOADED=1

aero7_confirm() {
  local prompt="$1"
  local default="${2:-no}"
  local reply

  if aero7_non_interactive; then
    [[ "$default" == "yes" ]]
    return $?
  fi

  if declare -F aero7_tui_backend >/dev/null 2>&1 && aero7_tui_backend; then
    if declare -F aero7_event_action_output >/dev/null 2>&1; then
      aero7_event_action_output "Prompt defaulted to $default: $prompt"
    fi
    [[ "$default" == "yes" ]]
    return $?
  fi

  while true; do
    if [[ "$default" == "yes" ]]; then
      printf '%s%s%s [Y/n] ' "${AERO7_C_BOLD:-}" "$prompt" "${AERO7_C_RESET:-}"
    else
      printf '%s%s%s [y/N] ' "${AERO7_C_BOLD:-}" "$prompt" "${AERO7_C_RESET:-}"
    fi
    read -r reply
    case "${reply:-$default}" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) printf 'Please answer yes or no.\n' ;;
    esac
  done
}

aero7_prompt_layout_choice() {
  if [[ "${AERO7_REPLACE_LAYOUT:-ask}" == "yes" ]]; then
    printf 'apply\n'
    return 0
  fi

  if aero7_non_interactive; then
    printf 'keep\n'
    return 0
  fi

  if declare -F aero7_tui_backend >/dev/null 2>&1 && aero7_tui_backend; then
    if declare -F aero7_event_action_output >/dev/null 2>&1; then
      aero7_event_action_output "Layout prompt defaulted to keep."
    fi
    printf 'keep\n'
    return 0
  fi

  if declare -F aero7_prompt_box >/dev/null 2>&1; then
    aero7_prompt_box \
      "Plasma layout" \
      "Applying the Aero7 layout will replace your current panels." \
      "A backup has already been created." \
      "Restore command: aero7 restore --latest" >&2
  else
    cat >&2 <<'EOF'

Plasma layout replacement

Applying the full Aero7-shell layout may replace existing panels and widgets.
A backup has already been created and can be restored with `aero7 restore`.
EOF
  fi

  cat >&2 <<'EOF'

1. Apply full Aero7-shell layout
2. Keep current layout and only install the theme
3. Cancel installation
EOF

  local reply
  while true; do
    printf 'Choose [1-3]: ' >&2
    read -r reply
    case "$reply" in
      1) printf 'apply\n'; return 0 ;;
      2) printf 'keep\n'; return 0 ;;
      3) printf 'cancel\n'; return 0 ;;
      *) printf 'Please choose 1, 2, or 3.\n' >&2 ;;
    esac
  done
}

aero7_prompt_optional_app() {
  local var_name="$1"
  local display_name="$2"
  local current_value="${!var_name:-ask}"

  case "$current_value" in
    yes)
      return 0
      ;;
    no)
      return 1
      ;;
  esac

  if aero7_non_interactive; then
    return 1
  fi

  aero7_confirm "Install optional $display_name?" "no"
}
