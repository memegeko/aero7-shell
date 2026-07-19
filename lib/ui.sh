#!/usr/bin/env bash

if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
  return 0
fi
AERO7_UI_LOADED=1

aero7_ui_init() {
  local locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"

  AERO7_UI_TTY=0
  [[ -t 1 ]] && AERO7_UI_TTY=1

  AERO7_UI_PLAIN=0
  if [[ "${AERO7_PLAIN:-0}" == "1" || "${TERM:-}" == "dumb" || "${CI:-}" == "true" || "$AERO7_UI_TTY" != "1" ]]; then
    AERO7_UI_PLAIN=1
  fi

  AERO7_UI_UNICODE=0
  if [[ "$AERO7_UI_PLAIN" != "1" && "$locale" =~ ([Uu][Tt][Ff]-?8) ]]; then
    AERO7_UI_UNICODE=1
  fi

  AERO7_UI_COLOR=0
  if [[ "$AERO7_UI_TTY" == "1" && "$AERO7_UI_PLAIN" != "1" && "${AERO7_NO_COLOR:-0}" != "1" && -z "${NO_COLOR:-}" ]]; then
    AERO7_UI_COLOR=1
  fi

  if [[ "$AERO7_UI_COLOR" == "1" ]]; then
    AERO7_C_RESET=$'\033[0m'
    AERO7_C_BLUE=$'\033[38;5;39m'
    AERO7_C_CYAN=$'\033[38;5;51m'
    AERO7_C_GREEN=$'\033[38;5;82m'
    AERO7_C_YELLOW=$'\033[38;5;220m'
    AERO7_C_RED=$'\033[38;5;196m'
    AERO7_C_DIM=$'\033[2m'
    AERO7_C_BOLD=$'\033[1m'
  else
    AERO7_C_RESET=""
    AERO7_C_BLUE=""
    AERO7_C_CYAN=""
    AERO7_C_GREEN=""
    AERO7_C_YELLOW=""
    AERO7_C_RED=""
    AERO7_C_DIM=""
    AERO7_C_BOLD=""
  fi

  if [[ "$AERO7_UI_UNICODE" == "1" ]]; then
    AERO7_ICON_OK="✓"
    AERO7_ICON_WARN="!"
    AERO7_ICON_FAIL="✗"
    AERO7_ICON_SKIP="○"
    AERO7_ICON_ACTION="→"
    AERO7_ICON_DETAIL="•"
  else
    AERO7_ICON_OK="[OK]"
    AERO7_ICON_WARN="[WARN]"
    AERO7_ICON_FAIL="[FAIL]"
    AERO7_ICON_SKIP="[SKIP]"
    AERO7_ICON_ACTION="[>]"
    AERO7_ICON_DETAIL="*"
  fi

  export AERO7_UI_TTY AERO7_UI_PLAIN AERO7_UI_UNICODE AERO7_UI_COLOR
}

aero7_ui_init

aero7_ui_quiet() {
  [[ "${AERO7_QUIET:-0}" == "1" && "${AERO7_DEBUG:-0}" != "1" ]]
}

aero7_ui_center_line() {
  local text="$1"
  local width="$2"
  local text_width="${#text}"
  local pad_left=0 pad_right=0
  if [[ "$text_width" -lt "$width" ]]; then
    pad_left=$(((width - text_width) / 2))
    pad_right=$((width - text_width - pad_left))
  fi
  printf '│%*s%s%*s│\n' "$pad_left" "" "$text" "$pad_right" ""
}

aero7_ui_rule() {
  local char="$1"
  local width="$2"
  local line
  printf -v line '%*s' "$width" ''
  printf '%s' "${line// /$char}"
}

aero7_ui_box() {
  local title="$1"
  local subtitle="${2:-}"
  local width=62
  local rule

  if [[ "$AERO7_UI_UNICODE" != "1" ]]; then
    printf '%s%s%s\n' "$AERO7_C_BOLD" "$title" "$AERO7_C_RESET"
    [[ -z "$subtitle" ]] || printf '%s%s%s\n' "$AERO7_C_CYAN" "$subtitle" "$AERO7_C_RESET"
    printf '\n'
    return 0
  fi

  rule="$(aero7_ui_rule "─" "$width")"
  printf '%s╭%s╮%s\n' "$AERO7_C_BLUE" "$rule" "$AERO7_C_RESET"
  printf '%s' "$AERO7_C_BLUE"
  aero7_ui_center_line "$title" "$width"
  if [[ -n "$subtitle" ]]; then
    printf '%s' "$AERO7_C_CYAN"
    aero7_ui_center_line "$subtitle" "$width"
  fi
  printf '%s╰%s╯%s\n\n' "$AERO7_C_BLUE" "$rule" "$AERO7_C_RESET"
}

aero7_stage_title() {
  case "$1" in
    00-preflight) printf 'Checking system\n' ;;
    10-backup) printf 'Creating backup\n' ;;
    20-system-update) printf 'Updating system\n' ;;
    30-base-dependencies) printf 'Installing base packages\n' ;;
    40-plasma-wayland) printf 'Installing Plasma Wayland\n' ;;
    50-yay) printf 'Preparing AUR helper\n' ;;
    60-aeroshell) printf 'Installing Aero desktop\n' ;;
    70-aero-applications) printf 'Installing applications\n' ;;
    80-plasma-layout) printf 'Applying Plasma layout\n' ;;
    90-sddm) printf 'Configuring SDDM\n' ;;
    100-plymouth) printf 'Configuring Plymouth\n' ;;
    110-fastfetch) printf 'Configuring Fastfetch\n' ;;
    120-wine) printf 'Configuring Wine\n' ;;
    130-terminal-compat) printf 'Installing terminal commands\n' ;;
    140-validation) printf 'Validating installation\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

aero7_format_duration() {
  local seconds="${1:-0}"
  if [[ "$seconds" -lt 60 ]]; then
    printf '%d seconds\n' "$seconds"
  else
    printf '%dm %02ds\n' "$((seconds / 60))" "$((seconds % 60))"
  fi
}

aero7_title() {
  aero7_ui_box "Aero7-shell Setup" "Windows 7-inspired desktop for Arch Linux"
  if aero7_ui_quiet; then
    return 0
  fi

  local system="Arch Linux"
  if declare -F aero7_read_os_release_value >/dev/null 2>&1; then
    system="$(aero7_read_os_release_value PRETTY_NAME 2>/dev/null || printf 'Arch Linux')"
  fi
  printf '  %sSystem%s      %s\n' "$AERO7_C_CYAN" "$AERO7_C_RESET" "$system"
  printf '  %sDesktop%s     KDE Plasma Wayland\n' "$AERO7_C_CYAN" "$AERO7_C_RESET"
  printf '  %sInstaller%s   Aero7-shell %s\n\n' "$AERO7_C_CYAN" "$AERO7_C_RESET" "$AERO7_VERSION"
}

aero7_stage_banner() {
  local stage="$1"
  local index="$2"
  local total="$3"
  local title width marker
  title="$(aero7_stage_title "$stage")"
  width="${#total}"
  printf -v marker '[ %*d/%d ]' "$width" "$index" "$total"
  printf '\n  %s%s%s %s%s%s\n' "$AERO7_C_BLUE" "$marker" "$AERO7_C_RESET" "$AERO7_C_BOLD" "$title" "$AERO7_C_RESET"
}

aero7_ui_status_line() {
  local color="$1"
  local icon="$2"
  shift 2
  printf '           %s%s%s %s\n' "$color" "$icon" "$AERO7_C_RESET" "$*"
}

aero7_ok() {
  aero7_ui_quiet && return 0
  aero7_ui_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "$*"
}

aero7_skip() {
  aero7_ui_quiet && return 0
  aero7_ui_status_line "$AERO7_C_DIM" "$AERO7_ICON_SKIP" "$*"
}

aero7_fail() {
  aero7_ui_status_line "$AERO7_C_RED" "$AERO7_ICON_FAIL" "$*"
}

aero7_warning_line() {
  aero7_ui_status_line "$AERO7_C_YELLOW" "$AERO7_ICON_WARN" "$*"
}

aero7_action() {
  aero7_ui_quiet && return 0
  aero7_ui_status_line "$AERO7_C_CYAN" "$AERO7_ICON_ACTION" "$*"
}

aero7_detail() {
  aero7_ui_quiet && return 0
  aero7_ui_status_line "$AERO7_C_DIM" "$AERO7_ICON_DETAIL" "$*"
}

aero7_progress_item() {
  aero7_ui_quiet && return 0
  local index="$1"
  local total="$2"
  shift 2
  printf '           %s[%d/%d]%s %s\n' "$AERO7_C_DIM" "$index" "$total" "$AERO7_C_RESET" "$*"
}

aero7_prompt_box() {
  local title="$1"
  shift
  if [[ "$AERO7_UI_UNICODE" != "1" ]]; then
    printf '\n%s\n' "$title"
    printf '%s\n' "$@"
    printf '\n'
    return 0
  fi
  local width=62 rule line
  rule="$(aero7_ui_rule "─" "$width")"
  printf '\n%s╭─ %s %s╮%s\n' "$AERO7_C_BLUE" "$title" "$(aero7_ui_rule "─" "$((width - ${#title} - 3))")" "$AERO7_C_RESET"
  for line in "$@"; do
    printf '%s│%s %-60s %s│%s\n' "$AERO7_C_BLUE" "$AERO7_C_RESET" "$line" "$AERO7_C_BLUE" "$AERO7_C_RESET"
  done
  printf '%s╰%s╯%s\n\n' "$AERO7_C_BLUE" "$rule" "$AERO7_C_RESET"
}

aero7_error_screen() {
  local message="$1"
  local stage="${AERO7_CURRENT_STAGE:-startup}"
  local title
  title="$(aero7_stage_title "$stage")"

  if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
    printf 'ERROR: %s\n' "$message" >&2
    return 0
  fi

  printf '\n' >&2
  if [[ "$AERO7_UI_UNICODE" == "1" ]]; then
    local width=62 rule
    rule="$(aero7_ui_rule "─" "$width")"
    printf '%s╭──────────────── Installation failed ────────────────╮%s\n' "$AERO7_C_RED" "$AERO7_C_RESET" >&2
    printf '%s│%s Stage: %-51s %s│%s\n' "$AERO7_C_RED" "$AERO7_C_RESET" "$title" "$AERO7_C_RED" "$AERO7_C_RESET" >&2
    printf '%s│%s Error: %-51s %s│%s\n' "$AERO7_C_RED" "$AERO7_C_RESET" "$message" "$AERO7_C_RED" "$AERO7_C_RESET" >&2
    printf '%s╰%s╯%s\n' "$AERO7_C_RED" "$rule" "$AERO7_C_RESET" >&2
  else
    printf 'Installation failed\n' >&2
    printf 'Stage: %s\n' "$title" >&2
    printf 'Error: %s\n' "$message" >&2
  fi
  if [[ -n "${AERO7_LOG_FILE:-}" ]]; then
    printf '\nLog:\n  %s\n' "$AERO7_LOG_FILE" >&2
  fi
  printf '\nResume after fixing the problem with:\n  ./install.sh --resume\n' >&2
}

aero7_summary() {
  aero7_ui_quiet && return 0
  cat <<'EOF'
Aero7-shell will install and configure a Plasma Wayland desktop inspired by Windows 7 Ultimate.

It will not install an X11 Plasma session, browser themes, Microsoft artwork, Microsoft fonts,
passwordless sudo rules, autologin, GPU driver overrides, or a replacement bootloader.
EOF
  printf '\n'
}
