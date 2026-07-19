#!/usr/bin/env bash

if [[ -n "${AERO7_LOGGING_LOADED:-}" ]]; then
  return 0
fi
AERO7_LOGGING_LOADED=1

aero7_logging_init() {
  local name="${1:-install}"
  aero7_detect_user
  AERO7_LOG_DIR="${AERO7_LOG_DIR:-$AERO7_HOME/.local/state/aero7-shell/logs}"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"

  if [[ "$(id -un)" == "$AERO7_USER" ]]; then
    mkdir -p -- "$AERO7_LOG_DIR"
  else
    sudo -H -u "$AERO7_USER" mkdir -p -- "$AERO7_LOG_DIR"
  fi

  AERO7_LOG_FILE="${AERO7_LOG_FILE:-$AERO7_LOG_DIR/$name-$stamp.log}"
  touch "$AERO7_LOG_FILE" 2>/dev/null || sudo -H -u "$AERO7_USER" touch "$AERO7_LOG_FILE"
  export AERO7_LOG_DIR AERO7_LOG_FILE
  aero7_log "INFO" "Log file: $AERO7_LOG_FILE"
}

aero7_log() {
  local level="$1"
  shift
  local message="$*"
  local stamp
  stamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] [%s] %s\n' "$stamp" "$level" "$message" >>"${AERO7_LOG_FILE:-/dev/null}" 2>/dev/null || true
  case "$level" in
    WARNING)
      if [[ -n "${AERO7_UI_LOADED:-}" ]] && declare -F aero7_warning_line >/dev/null 2>&1; then
        aero7_warning_line "$message" >&2
      else
        printf 'WARNING: %s\n' "$message" >&2
      fi
      ;;
    ERROR)
      if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
        printf '[%s] [%s] %s\n' "$stamp" "$level" "$message" >&2
      fi
      ;;
    *)
      if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
        printf '[%s] [%s] %s\n' "$stamp" "$level" "$message"
      fi
      ;;
  esac
}

aero7_unexpected_error() {
  local line="$1"
  local code="$2"
  local source="${BASH_SOURCE[1]:-unknown}"
  local function="${FUNCNAME[1]:-main}"
  local stage="${AERO7_CURRENT_STAGE:-startup}"
  local message="Unexpected failure at $source:$line in $function during $stage (exit $code)."
  aero7_log "ERROR" "$message"
  if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
    local i
    printf 'Stack:\n' >&2
    for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
      printf '  %s at %s:%s\n' "${FUNCNAME[$i]}" "${BASH_SOURCE[$i]:-unknown}" "${BASH_LINENO[$((i - 1))]:-unknown}" >&2
    done
  elif declare -F aero7_error_screen >/dev/null 2>&1; then
    aero7_error_screen "$message"
  else
    printf 'ERROR: %s\n' "$message" >&2
  fi
}
