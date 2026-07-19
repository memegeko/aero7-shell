#!/usr/bin/env bash

if [[ -n "${AERO7_COMMON_LOADED:-}" ]]; then
  return 0
fi
AERO7_COMMON_LOADED=1

export AERO7_PROJECT_NAME="Aero7-shell"
AERO7_VERSION="${AERO7_VERSION:-0.1.0}"
AERO7_REPOSITORY="${AERO7_REPOSITORY:-memegeko/Aero7-shell}"
export AERO7_SESSION="wayland"

aero7_repo_root() {
  if [[ -n "${AERO7_PROJECT_ROOT:-}" ]]; then
    printf '%s\n' "$AERO7_PROJECT_ROOT"
    return 0
  fi

  local source_dir
  source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || return 1
  cd -- "$source_dir/.." && pwd -P
}

aero7_have() {
  command -v "$1" >/dev/null 2>&1
}

aero7_is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

aero7_log_or_print() {
  local level="$1"
  shift
  if declare -F aero7_log >/dev/null 2>&1; then
    aero7_log "$level" "$*"
  else
    printf '%s: %s\n' "$level" "$*" >&2
  fi
}

aero7_die() {
  local message="$*"
  aero7_log_or_print "ERROR" "$message"
  if [[ "${AERO7_DEBUG:-0}" != "1" ]] && declare -F aero7_error_screen >/dev/null 2>&1; then
    aero7_error_screen "$message"
  elif [[ "${AERO7_DEBUG:-0}" != "1" ]]; then
    printf 'ERROR: %s\n' "$message" >&2
  fi
  exit 1
}

aero7_warn() {
  aero7_log_or_print "WARNING" "$*"
  if [[ "${AERO7_RECORD_WARNINGS:-0}" == "1" ]] && declare -F aero7_state_append >/dev/null 2>&1; then
    aero7_state_append "warnings" "$*" || true
  fi
}

aero7_info() {
  aero7_log_or_print "INFO" "$*"
}

aero7_debug() {
  if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
    aero7_log_or_print "DEBUG" "$*"
  fi
}

aero7_action() {
  aero7_info "$*"
}

aero7_detail() {
  aero7_info "$*"
}

aero7_ok() {
  aero7_info "$*"
}

aero7_skip() {
  aero7_info "$*"
}

aero7_fail() {
  aero7_log_or_print "ERROR" "$*"
}

aero7_warning_line() {
  aero7_log_or_print "WARNING" "$*"
}

aero7_progress_item() {
  aero7_info "[$1/$2] ${*:3}"
}

aero7_detect_user() {
  if [[ -z "${AERO7_USER:-}" ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
      AERO7_USER="$SUDO_USER"
    else
      AERO7_USER="$(id -un)"
    fi
  fi

  if [[ -z "${AERO7_HOME:-}" ]]; then
    AERO7_HOME="$(getent passwd "$AERO7_USER" | awk -F: '{print $6}')"
  fi

  [[ -n "$AERO7_HOME" ]] || aero7_die "Could not determine home directory for $AERO7_USER."
  export AERO7_USER AERO7_HOME
}

aero7_init_paths() {
  aero7_detect_user
  AERO7_ROOT="$(aero7_repo_root)"
  AERO7_CONFIG_DIR="$AERO7_ROOT/config"
  AERO7_LIB_DIR="$AERO7_ROOT/lib"
  AERO7_STAGE_DIR="$AERO7_ROOT/stages"
  AERO7_RECIPE_DIR="$AERO7_ROOT/recipes"
  AERO7_CACHE_DIR="${AERO7_CACHE_DIR:-$AERO7_HOME/.cache/aero7-shell}"
  AERO7_USER_STATE_DIR="${AERO7_USER_STATE_DIR:-$AERO7_HOME/.local/state/aero7-shell}"
  AERO7_SYSTEM_STATE_DIR="${AERO7_SYSTEM_STATE_DIR:-/var/lib/aero7-shell}"
  AERO7_SYSTEM_LIB_DIR="${AERO7_SYSTEM_LIB_DIR:-/usr/local/lib/aero7-shell}"
  AERO7_SYSTEM_BIN_DIR="${AERO7_SYSTEM_BIN_DIR:-/usr/local/bin}"
  AERO7_ASSET_DIR="${AERO7_ASSET_DIR:-/usr/share/aero7-shell}"
  export AERO7_ROOT AERO7_CONFIG_DIR AERO7_LIB_DIR AERO7_STAGE_DIR AERO7_RECIPE_DIR
  export AERO7_CACHE_DIR AERO7_USER_STATE_DIR AERO7_SYSTEM_STATE_DIR
  export AERO7_SYSTEM_LIB_DIR AERO7_SYSTEM_BIN_DIR AERO7_ASSET_DIR
}

aero7_dry_run() {
  [[ "${AERO7_DRY_RUN:-0}" == "1" ]]
}

aero7_non_interactive() {
  [[ "${AERO7_NON_INTERACTIVE:-0}" == "1" ]]
}

aero7_shell_join() {
  local out=""
  local item
  for item in "$@"; do
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="$out $item"
    fi
  done
  printf '%s\n' "$out"
}

aero7_quote_args() {
  local out="" quoted item
  for item in "$@"; do
    printf -v quoted '%q' "$item"
    if [[ -z "$out" ]]; then
      out="$quoted"
    else
      out="$out $quoted"
    fi
  done
  printf '%s\n' "$out"
}

aero7_print_command_excerpt() {
  local capture="$1"
  local lines="${2:-25}"
  [[ -s "$capture" ]] || {
    if declare -F aero7_detail >/dev/null 2>&1; then
      aero7_detail "No command output was captured."
    else
      printf 'No command output was captured.\n' >&2
    fi
    return 0
  }

  printf '\n    Last output:\n' >&2
  tail -n "$lines" "$capture" | sed 's/^/      /' >&2
}

aero7_log_command_capture() {
  local capture="$1"
  local code="$2"
  local command_string="$3"
  local stage="$4"
  local run_user="$5"
  local sudo_used="$6"
  local source_file="$7"
  local function_name="$8"
  local line_number="$9"
  local log="${AERO7_LOG_FILE:-/dev/null}"
  local stamp
  stamp="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    printf '\n[%s] [COMMAND] stage=%s function=%s source=%s line=%s cwd=%s user=%s sudo=%s exit=%s\n' \
      "$stamp" "$stage" "$function_name" "$source_file" "$line_number" "$PWD" "$run_user" "$sudo_used" "$code"
    printf '[%s] [COMMAND] argv=%s\n' "$stamp" "$command_string"
    printf -- '--- command output begin ---\n'
    cat "$capture"
    printf -- '\n--- command output end ---\n'
  } >>"$log" 2>/dev/null || true
}

aero7_run_command_capture() {
  local label="$1"
  shift
  [[ "$#" -gt 0 ]] || aero7_die "Internal error: command runner called without a command."

  local command_string stage run_user sudo_used stream source_file function_name line_number capture code log
  command_string="$(aero7_quote_args "$@")"
  stage="${AERO7_CURRENT_STAGE:-startup}"
  run_user="${AERO7_COMMAND_RUN_USER:-$(id -un 2>/dev/null || printf unknown)}"
  sudo_used="${AERO7_COMMAND_SUDO:-0}"
  stream="${AERO7_COMMAND_STREAM:-0}"
  source_file="${BASH_SOURCE[1]:-unknown}"
  function_name="${FUNCNAME[1]:-main}"
  line_number="${BASH_LINENO[0]:-unknown}"
  log="${AERO7_LOG_FILE:-/dev/null}"

  if aero7_dry_run; then
    [[ -z "$label" ]] || aero7_action "$label"
    if declare -F aero7_detail >/dev/null 2>&1; then
      aero7_detail "Would run: $command_string"
    else
      printf 'Would run: %s\n' "$command_string"
    fi
    aero7_log_or_print "INFO" "DRY-RUN command stage=$stage function=$function_name source=$source_file line=$line_number cwd=$PWD user=$run_user sudo=$sudo_used argv=$command_string"
    return 0
  fi

  [[ -z "$label" ]] || aero7_action "$label"
  aero7_log_or_print "INFO" "COMMAND start stage=$stage function=$function_name source=$source_file line=$line_number cwd=$PWD user=$run_user sudo=$sudo_used argv=$command_string"

  if [[ "${AERO7_DEBUG:-0}" == "1" || "$stream" == "1" ]]; then
    if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
      printf '+ %s\n' "$command_string" >&2
    fi
    {
      printf '\n[%s] [COMMAND] stage=%s function=%s source=%s line=%s cwd=%s user=%s sudo=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$stage" "$function_name" "$source_file" "$line_number" "$PWD" "$run_user" "$sudo_used"
      printf '[COMMAND] argv=%s\n' "$command_string"
      printf -- '--- command output begin ---\n'
    } >>"$log" 2>/dev/null || true
    if "$@" > >(tee -a "$log") 2> >(tee -a "$log" >&2); then
      code=0
    else
      code=$?
    fi
    printf '\n--- command output end (exit %s) ---\n' "$code" >>"$log" 2>/dev/null || true
  else
    capture="$(mktemp "${TMPDIR:-/tmp}/aero7-command.XXXXXX")" || return 1
    if "$@" >"$capture" 2>&1; then
      code=0
    else
      code=$?
    fi
    aero7_log_command_capture "$capture" "$code" "$command_string" "$stage" "$run_user" "$sudo_used" "$source_file" "$function_name" "$line_number"
  fi

  if [[ "$code" -eq 0 ]]; then
    aero7_log_or_print "INFO" "COMMAND success stage=$stage exit=0 argv=$command_string"
    if [[ -n "${capture:-}" ]]; then
      rm -f -- "$capture"
    fi
    return 0
  fi

  aero7_log_or_print "ERROR" "COMMAND failed stage=$stage exit=$code argv=$command_string"
  if [[ -n "$label" ]]; then
    aero7_fail "$label failed"
  else
    aero7_fail "Command failed: ${1##*/}"
  fi
  if [[ "${AERO7_DEBUG:-0}" != "1" && "$stream" != "1" && -n "${capture:-}" ]]; then
    aero7_print_command_excerpt "$capture" 25
  fi
  if [[ -n "${AERO7_LOG_FILE:-}" ]]; then
    printf '\n    Full log:\n      %s\n' "$AERO7_LOG_FILE" >&2
  fi
  if [[ -n "${capture:-}" ]]; then
    rm -f -- "$capture"
  fi
  return "$code"
}

aero7_run_shell() {
  local label="$1"
  local script="$2"
  shift 2
  aero7_run_command_capture "$label" bash -lc "$script" _ "$@"
}

aero7_run_with_repeated_input() {
  local label="$1"
  local input="$2"
  shift 2
  [[ "$#" -gt 0 ]] || aero7_die "Internal error: piped command runner called without a command."

  local command_string stage run_user sudo_used stream source_file function_name line_number capture code log
  local had_errexit=0
  local pipe_status=()
  command_string="yes $(printf '%q' "$input") | $(aero7_quote_args "$@")"
  stage="${AERO7_CURRENT_STAGE:-startup}"
  run_user="${AERO7_COMMAND_RUN_USER:-$(id -un 2>/dev/null || printf unknown)}"
  sudo_used="${AERO7_COMMAND_SUDO:-0}"
  stream="${AERO7_COMMAND_STREAM:-0}"
  source_file="${BASH_SOURCE[1]:-unknown}"
  function_name="${FUNCNAME[1]:-main}"
  line_number="${BASH_LINENO[0]:-unknown}"
  log="${AERO7_LOG_FILE:-/dev/null}"

  if aero7_dry_run; then
    [[ -z "$label" ]] || aero7_action "$label"
    aero7_detail "Would run: $command_string"
    aero7_log_or_print "INFO" "DRY-RUN command stage=$stage function=$function_name source=$source_file line=$line_number cwd=$PWD user=$run_user sudo=$sudo_used argv=$command_string"
    return 0
  fi

  [[ -z "$label" ]] || aero7_action "$label"
  aero7_log_or_print "INFO" "COMMAND start stage=$stage function=$function_name source=$source_file line=$line_number cwd=$PWD user=$run_user sudo=$sudo_used argv=$command_string"

  [[ $- == *e* ]] && {
    had_errexit=1
    set +e
  }
  if [[ "${AERO7_DEBUG:-0}" == "1" || "$stream" == "1" ]]; then
    if [[ "${AERO7_DEBUG:-0}" == "1" ]]; then
      printf '+ %s\n' "$command_string" >&2
    fi
    {
      printf '\n[%s] [COMMAND] stage=%s function=%s source=%s line=%s cwd=%s user=%s sudo=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$stage" "$function_name" "$source_file" "$line_number" "$PWD" "$run_user" "$sudo_used"
      printf '[COMMAND] argv=%s\n' "$command_string"
      printf -- '--- command output begin ---\n'
    } >>"$log" 2>/dev/null || true
    { yes "$input" || true; } | "$@" > >(tee -a "$log") 2> >(tee -a "$log" >&2)
    pipe_status=("${PIPESTATUS[@]}")
    code="${pipe_status[1]:-1}"
    printf '\n--- command output end (exit %s) ---\n' "$code" >>"$log" 2>/dev/null || true
  else
    capture="$(mktemp "${TMPDIR:-/tmp}/aero7-command.XXXXXX")" || {
      [[ "$had_errexit" -eq 1 ]] && set -e
      return 1
    }
    { yes "$input" || true; } | "$@" >"$capture" 2>&1
    pipe_status=("${PIPESTATUS[@]}")
    code="${pipe_status[1]:-1}"
    aero7_log_command_capture "$capture" "$code" "$command_string" "$stage" "$run_user" "$sudo_used" "$source_file" "$function_name" "$line_number"
  fi
  [[ "$had_errexit" -eq 1 ]] && set -e

  if [[ "$code" -eq 0 ]]; then
    aero7_log_or_print "INFO" "COMMAND success stage=$stage exit=0 argv=$command_string"
    [[ -z "${capture:-}" ]] || rm -f -- "$capture"
    return 0
  fi

  aero7_log_or_print "ERROR" "COMMAND failed stage=$stage exit=$code argv=$command_string"
  if [[ -n "$label" ]]; then
    aero7_fail "$label failed"
  else
    aero7_fail "Command failed: ${1##*/}"
  fi
  if [[ "${AERO7_DEBUG:-0}" != "1" && "$stream" != "1" && -n "${capture:-}" ]]; then
    aero7_print_command_excerpt "$capture" 25
  fi
  if [[ -n "${AERO7_LOG_FILE:-}" ]]; then
    printf '\n    Full log:\n      %s\n' "$AERO7_LOG_FILE" >&2
  fi
  [[ -z "${capture:-}" ]] || rm -f -- "$capture"
  return "$code"
}

aero7_run() {
  aero7_run_command_capture "${AERO7_COMMAND_LABEL:-}" "$@"
}

aero7_sudo() {
  if aero7_is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

aero7_sudo_keepalive_start() {
  if aero7_dry_run || aero7_is_root; then
    return 0
  fi
  if [[ -n "${AERO7_SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$AERO7_SUDO_KEEPALIVE_PID" 2>/dev/null; then
    return 0
  fi
  if ! aero7_have sudo; then
    aero7_die "sudo is required for privileged install steps."
  fi

  if declare -F aero7_action >/dev/null 2>&1; then
    aero7_action "Validating sudo access"
  else
    aero7_info "Validating sudo once for this run."
  fi
  sudo -v || aero7_die "Could not validate sudo credentials."
  if declare -F aero7_ok >/dev/null 2>&1; then
    aero7_ok "sudo access confirmed"
  fi
  (
    while true; do
      sleep 60
      sudo -n -v >/dev/null 2>&1 || exit 0
    done
  ) &
  AERO7_SUDO_KEEPALIVE_PID="$!"
  export AERO7_SUDO_KEEPALIVE_PID
}

aero7_sudo_keepalive_stop() {
  local pid="${AERO7_SUDO_KEEPALIVE_PID:-}"
  [[ -n "$pid" ]] || return 0
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  unset AERO7_SUDO_KEEPALIVE_PID
}

aero7_sudo_run() {
  local sudo_used=0
  local command=("$@")
  if ! aero7_is_root; then
    command=(sudo "$@")
    sudo_used=1
  fi
  AERO7_COMMAND_SUDO="$sudo_used" AERO7_COMMAND_RUN_USER="root" aero7_run_command_capture "${AERO7_COMMAND_LABEL:-}" "${command[@]}"
}

aero7_user_run() {
  aero7_detect_user
  local command=()
  if [[ "$(id -un)" == "$AERO7_USER" ]]; then
    command=(env "HOME=$AERO7_HOME" "$@")
  else
    command=(sudo -H -u "$AERO7_USER" env "HOME=$AERO7_HOME" "$@")
  fi
  AERO7_COMMAND_RUN_USER="$AERO7_USER" aero7_run_command_capture "${AERO7_COMMAND_LABEL:-}" "${command[@]}"
}

aero7_install_root_file() {
  local source="$1"
  local dest="$2"
  local mode="${3:-0644}"

  [[ -n "$source" && -n "$dest" ]] || aero7_die "Internal error: empty source or destination."
  if aero7_dry_run; then
    aero7_info "Would install $source to $dest."
    return 0
  fi
  aero7_sudo install -D -m "$mode" "$source" "$dest"
}

aero7_write_root_text() {
  local dest="$1"
  local mode="${2:-0644}"
  local tmp
  tmp="$(mktemp)" || return 1
  cat >"$tmp"
  if aero7_dry_run; then
    aero7_info "Would write $dest."
    rm -f -- "$tmp"
    return 0
  fi
  aero7_sudo install -D -m "$mode" "$tmp" "$dest"
  rm -f -- "$tmp"
}

aero7_read_os_release_value() {
  local key="$1"
  local file="${AERO7_OS_RELEASE:-${AERO7_TEST_ROOT:-}/etc/os-release}"
  [[ -r "$file" ]] || return 1
  awk -F= -v want="$key" '
    $1 == want {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

aero7_is_arch_linux() {
  local id id_like
  id="$(aero7_read_os_release_value ID || true)"
  id_like="$(aero7_read_os_release_value ID_LIKE || true)"
  [[ "$id" == "arch" || " $id_like " == *" arch "* ]]
}

aero7_require_arch_or_dry_run() {
  if aero7_is_arch_linux; then
    return 0
  fi
  if aero7_dry_run; then
    aero7_warn "This does not appear to be Arch Linux; continuing because --dry-run is active."
    return 0
  fi
  aero7_die "Aero7-shell currently supports Arch Linux only."
}

aero7_refuse_root_install() {
  if aero7_is_root; then
    aero7_die "Run Aero7-shell as a normal sudo-capable user, not as root."
  fi
}

aero7_valid_key() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+$ ]]
}

aero7_path_under() {
  local path="$1"
  local base="$2"
  [[ "$path" == "$base" || "$path" == "$base"/* ]]
}

aero7_canonical_path() {
  local path="$1"
  if aero7_have realpath; then
    realpath -m -- "$path"
  else
    printf '%s\n' "$path"
  fi
}

aero7_reject_dangerous_path() {
  local path="$1"
  local canonical
  [[ -n "$path" ]] || aero7_die "Refusing to operate on an empty path."
  canonical="$(aero7_canonical_path "$path")"
  case "$canonical" in
    /|/home|/usr|/etc|/boot)
      aero7_die "Refusing dangerous path: $canonical"
      ;;
  esac
  if [[ -n "${AERO7_HOME:-}" && "$canonical" == "$(aero7_canonical_path "$AERO7_HOME")" ]]; then
    aero7_die "Refusing to operate on the user's entire home directory."
  fi
}

aero7_safe_remove_tree() {
  local path="$1"
  local allowed_base="$2"
  local canonical_path canonical_base
  [[ -n "$allowed_base" ]] || aero7_die "Refusing to remove without an allowed base."
  aero7_reject_dangerous_path "$path"
  canonical_path="$(aero7_canonical_path "$path")"
  canonical_base="$(aero7_canonical_path "$allowed_base")"
  aero7_path_under "$canonical_path" "$canonical_base" || aero7_die "Refusing to remove $canonical_path outside $canonical_base."
  aero7_sudo_run rm -rf -- "$path"
}

aero7_safe_remove_file() {
  local path="$1"
  local allowed_base="$2"
  local canonical_path canonical_base
  [[ -n "$allowed_base" ]] || aero7_die "Refusing to remove without an allowed base."
  aero7_reject_dangerous_path "$path"
  canonical_path="$(aero7_canonical_path "$path")"
  canonical_base="$(aero7_canonical_path "$allowed_base")"
  aero7_path_under "$canonical_path" "$canonical_base" || aero7_die "Refusing to remove $canonical_path outside $canonical_base."
  [[ -f "$path" || -L "$path" ]] || aero7_die "Refusing to remove non-file path: $path"
  aero7_sudo_run rm -f -- "$path"
}

aero7_file_sha256() {
  local file="$1"
  sha256sum "$file" | awk '{print $1}'
}

aero7_backup_file_before_edit() {
  local source="$1"
  local label="${2:-file-edit}"
  local stamp rel root dest
  [[ -f "$source" ]] || aero7_die "Cannot back up missing file: $source"
  stamp="$(date +%Y%m%d-%H%M%S)"
  rel="${source#/}"
  if aero7_dry_run; then
    root="$AERO7_USER_STATE_DIR/dry-run/backups/file-edits/$stamp/$label"
    mkdir -p -- "$root/$(dirname -- "$rel")"
    dest="$root/$rel"
    cp -p -- "$source" "$dest"
  else
    root="$AERO7_SYSTEM_STATE_DIR/backups/file-edits/$stamp/$label"
    dest="$root/$rel"
    aero7_sudo_run install -d -m 0755 "$(dirname -- "$dest")"
    aero7_sudo_run cp -p -- "$source" "$dest"
  fi
  AERO7_LAST_FILE_BACKUP="$dest"
  export AERO7_LAST_FILE_BACKUP
  if declare -F aero7_state_append >/dev/null 2>&1; then
    aero7_state_append "configuration_backups" "$source -> $dest"
  fi
  printf '%s\n' "$dest"
}

aero7_restore_file_backup() {
  local backup="$1"
  local dest="$2"
  [[ -n "$backup" && -f "$backup" ]] || aero7_die "Cannot restore missing backup: $backup"
  [[ -n "$dest" ]] || aero7_die "Cannot restore to an empty path."
  aero7_sudo_run install -D -m "$(stat -c '%a' "$backup")" "$backup" "$dest"
}

aero7_replace_file_safely() {
  local original="$1"
  local proposed="$2"
  local label="$3"
  local validator="${4:-}"
  local original_sum proposed_sum backup owner group mode dir base tmp_target

  [[ -f "$original" ]] || aero7_die "Cannot edit missing file: $original"
  [[ -f "$proposed" ]] || aero7_die "Proposed file missing: $proposed"

  original_sum="$(aero7_file_sha256 "$original")"
  proposed_sum="$(aero7_file_sha256 "$proposed")"
  if [[ "$original_sum" == "$proposed_sum" ]]; then
    aero7_info "No changes needed for $original."
    return 0
  fi

  if [[ -n "$validator" ]]; then
    aero7_valid_key "$validator" || aero7_die "Invalid validator name: $validator"
    declare -F "$validator" >/dev/null 2>&1 || aero7_die "Validator not found: $validator"
    "$validator" "$proposed" || aero7_die "Proposed $label file failed validation: $proposed"
  fi

  backup="$(aero7_backup_file_before_edit "$original" "$label")"
  AERO7_LAST_FILE_BACKUP="$backup"
  export AERO7_LAST_FILE_BACKUP
  aero7_info "Checksum before $label edit: $original_sum"
  aero7_info "Checksum after $label edit:  $proposed_sum"
  if [[ -n "${AERO7_LOG_FILE:-}" ]]; then
    {
      printf '\n--- Proposed %s change for %s ---\n' "$label" "$original"
      diff -u -- "$original" "$proposed" || true
    } >>"$AERO7_LOG_FILE"
  fi

  if aero7_dry_run; then
    aero7_info "Would atomically replace $original; backup would be $backup."
    return 0
  fi

  owner="$(stat -c '%u' "$original")"
  group="$(stat -c '%g' "$original")"
  mode="$(stat -c '%a' "$original")"
  dir="$(dirname -- "$original")"
  base="$(basename -- "$original")"
  tmp_target="$(aero7_sudo mktemp "$dir/.aero7-$base.XXXXXX")"
  aero7_sudo install -m "$mode" -o "$owner" -g "$group" "$proposed" "$tmp_target"
  aero7_sudo mv -f -- "$tmp_target" "$original"

  if declare -F aero7_state_append >/dev/null 2>&1; then
    aero7_state_append "modified_files" "$original"
  fi
}

aero7_has_word() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

aero7_words_add_unique() {
  local existing="$1"
  shift
  local words=()
  local word
  read -r -a words <<<"$existing"
  for word in "$@"; do
    if ! aero7_has_word "$word" "${words[@]}"; then
      words+=("$word")
    fi
  done
  aero7_shell_join "${words[@]}"
}

aero7_config_value() {
  local key="$1"
  local file="${2:-$AERO7_CONFIG_DIR/aero7.conf}"
  [[ -r "$file" ]] || return 1
  awk -F= -v want="$key" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    $1 == want {
      value = $2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      print value
      exit
    }
  ' "$file"
}

aero7_load_package_file() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { print $1 }
  ' "$file"
}
