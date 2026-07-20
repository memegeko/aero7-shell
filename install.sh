#!/usr/bin/env bash
set -Eeuo pipefail

AERO7_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export AERO7_PROJECT_ROOT

# shellcheck source=lib/common.sh
source "$AERO7_PROJECT_ROOT/lib/common.sh"

AERO7_BACKEND_RUN=0
AERO7_ASSUME_YES=1
AERO7_NON_INTERACTIVE=1
AERO7_DRY_RUN=0
AERO7_DEBUG="${AERO7_DEBUG:-0}"
AERO7_NO_COLOR="${AERO7_NO_COLOR:-0}"
AERO7_PLAIN="${AERO7_PLAIN:-0}"
AERO7_QUIET="${AERO7_QUIET:-0}"
AERO7_TUI="${AERO7_TUI:-0}"
AERO7_TUI_REQUESTED=0
AERO7_UI_DIAGNOSTICS=0
AERO7_UI_DEMO=""
AERO7_INTERACTIVE_REQUESTED=0
AERO7_RESUME=0
AERO7_NO_REBOOT=0
AERO7_REPLACE_LAYOUT="ask"
AERO7_INSTALL_WINXPLORER="ask"
AERO7_INSTALL_SEVULET="ask"
AERO7_RESTART_STAGE=""
AERO7_SKIP_STAGES=()
AERO7_REBOOT="ask"
AERO7_PACKAGE_MODE="${AERO7_PACKAGE_MODE:-auto}"
AERO7_ALLOW_SOURCE_FALLBACK="${AERO7_ALLOW_SOURCE_FALLBACK:-0}"

usage() {
  cat <<EOF
Aero7-shell installer $AERO7_VERSION

Usage: ./install.sh [options]

Options:
  --help                 Show this help
  --version              Show version
  --yes                  Assume yes for ordinary confirmations (default)
  --non-interactive      Avoid prompts; keep layout and skip optional apps (default)
  --interactive          Ask prompts instead of using the default unattended mode
  --dry-run              Print planned actions without changing the system
  --no-color             Disable ANSI colors
  --plain                Use simple ASCII line output
  --quiet                Show only stages, warnings, failures, and summary
  --debug                Stream command output and enable diagnostics
  --tui                  Force the full-screen curses interface
  --ui-diagnostics       Explain UI mode selection
  --ui-demo MODE         Run a curses UI demo
  --resume               Resume from saved state
  --restart-stage STAGE  Restart from a specific stage id
  --skip-stage STAGE     Skip a specific stage id
  --no-reboot            Never prompt to reboot
  --binary-packages      Require signed Aero7 binary packages
  --source-build         Build Aero packages from AUR source recipes
  --allow-source-fallback
                          Allow AUR source build fallback if binary packages fail
  --replace-layout       Apply the full Aero7-shell Plasma layout
  --keep-layout          Keep current Plasma layout
  --install-winxplorer   Include optional WinXplorer recipe if available
  --install-sevulet      Include optional Sevulet recipe if available
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --backend-run) AERO7_BACKEND_RUN=1 ;;
    --help) usage; exit 0 ;;
    --version) printf '%s\n' "$AERO7_VERSION"; exit 0 ;;
    --yes) AERO7_ASSUME_YES=1 ;;
    --non-interactive) AERO7_NON_INTERACTIVE=1 ;;
    --interactive) AERO7_ASSUME_YES=0; AERO7_NON_INTERACTIVE=0; AERO7_INTERACTIVE_REQUESTED=1 ;;
    --dry-run) AERO7_DRY_RUN=1 ;;
    --no-color) AERO7_NO_COLOR=1 ;;
    --plain) AERO7_PLAIN=1 ;;
    --quiet) AERO7_QUIET=1 ;;
    --debug) AERO7_DEBUG=1 ;;
    --tui) AERO7_TUI=1; AERO7_TUI_REQUESTED=1 ;;
    --ui-diagnostics) AERO7_UI_DIAGNOSTICS=1 ;;
    --ui-demo)
      shift
      [[ "$#" -gt 0 ]] || aero7_die "--ui-demo requires a mode."
      AERO7_UI_DEMO="$1"
      AERO7_TUI=1
      AERO7_TUI_REQUESTED=1
      ;;
    --resume) AERO7_RESUME=1 ;;
    --restart-stage)
      shift
      [[ "$#" -gt 0 ]] || aero7_die "--restart-stage requires a value."
      AERO7_RESTART_STAGE="$1"
      ;;
    --skip-stage)
      shift
      [[ "$#" -gt 0 ]] || aero7_die "--skip-stage requires a value."
      AERO7_SKIP_STAGES+=("$1")
      ;;
    --no-reboot) AERO7_NO_REBOOT=1; AERO7_REBOOT=no ;;
    --binary-packages) AERO7_PACKAGE_MODE=binary ;;
    --source-build) AERO7_PACKAGE_MODE=source ;;
    --allow-source-fallback) AERO7_ALLOW_SOURCE_FALLBACK=1 ;;
    --replace-layout) AERO7_REPLACE_LAYOUT=yes ;;
    --keep-layout) AERO7_REPLACE_LAYOUT=no ;;
    --install-winxplorer) AERO7_INSTALL_WINXPLORER=yes ;;
    --install-sevulet) AERO7_INSTALL_SEVULET=yes ;;
    *)
      aero7_die "Unknown installer option: $1"
      ;;
  esac
  shift
done

export AERO7_ASSUME_YES AERO7_NON_INTERACTIVE AERO7_DRY_RUN AERO7_DEBUG
export AERO7_NO_COLOR AERO7_PLAIN AERO7_QUIET AERO7_TUI
export AERO7_RESUME AERO7_NO_REBOOT AERO7_REPLACE_LAYOUT
export AERO7_INSTALL_WINXPLORER AERO7_INSTALL_SEVULET AERO7_REBOOT
export AERO7_PACKAGE_MODE AERO7_ALLOW_SOURCE_FALLBACK AERO7_BACKEND_RUN

if [[ "$AERO7_DEBUG" == "1" ]]; then
  export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}:stage=${AERO7_CURRENT_STAGE:-startup}: '
  set -x
fi

# shellcheck source=lib/logging.sh
source "$AERO7_PROJECT_ROOT/lib/logging.sh"
# shellcheck source=lib/ui-events.sh
source "$AERO7_PROJECT_ROOT/lib/ui-events.sh"
# shellcheck source=lib/ui-controller.sh
source "$AERO7_PROJECT_ROOT/lib/ui-controller.sh"
# shellcheck source=lib/ui.sh
source "$AERO7_PROJECT_ROOT/lib/ui.sh"
# shellcheck source=lib/prompts.sh
source "$AERO7_PROJECT_ROOT/lib/prompts.sh"
# shellcheck source=lib/state.sh
source "$AERO7_PROJECT_ROOT/lib/state.sh"
# shellcheck source=lib/backup.sh
source "$AERO7_PROJECT_ROOT/lib/backup.sh"
# shellcheck source=lib/packages.sh
source "$AERO7_PROJECT_ROOT/lib/packages.sh"
# shellcheck source=lib/repository-key.sh
source "$AERO7_PROJECT_ROOT/lib/repository-key.sh"
# shellcheck source=lib/binary-repo.sh
source "$AERO7_PROJECT_ROOT/lib/binary-repo.sh"
# shellcheck source=lib/aur.sh
source "$AERO7_PROJECT_ROOT/lib/aur.sh"
# shellcheck source=lib/systemd.sh
source "$AERO7_PROJECT_ROOT/lib/systemd.sh"
# shellcheck source=lib/bootloader.sh
source "$AERO7_PROJECT_ROOT/lib/bootloader.sh"
# shellcheck source=lib/initramfs.sh
source "$AERO7_PROJECT_ROOT/lib/initramfs.sh"
# shellcheck source=lib/plasma.sh
source "$AERO7_PROJECT_ROOT/lib/plasma.sh"
# shellcheck source=lib/assets.sh
source "$AERO7_PROJECT_ROOT/lib/assets.sh"
# shellcheck source=lib/applications.sh
source "$AERO7_PROJECT_ROOT/lib/applications.sh"
# shellcheck source=lib/commands.sh
source "$AERO7_PROJECT_ROOT/lib/commands.sh"
# shellcheck source=lib/validation.sh
source "$AERO7_PROJECT_ROOT/lib/validation.sh"
# shellcheck source=lib/ownership.sh
source "$AERO7_PROJECT_ROOT/lib/ownership.sh"

trap 'aero7_unexpected_error "$LINENO" "$?"' ERR

aero7_init_paths

if [[ "$AERO7_UI_DIAGNOSTICS" == "1" ]]; then
  aero7_ui_diagnostics
  exit 0
fi

build_backend_args() {
  local args=(--backend-run)
  [[ "$AERO7_DRY_RUN" == "1" ]] && args+=(--dry-run)
  [[ "$AERO7_NO_REBOOT" == "1" ]] && args+=(--no-reboot)
  [[ "$AERO7_RESUME" == "1" ]] && args+=(--resume)
  [[ "$AERO7_INTERACTIVE_REQUESTED" == "1" ]] && args+=(--interactive)
  [[ "$AERO7_PACKAGE_MODE" == "binary" ]] && args+=(--binary-packages)
  [[ "$AERO7_PACKAGE_MODE" == "source" ]] && args+=(--source-build)
  [[ "$AERO7_ALLOW_SOURCE_FALLBACK" == "1" ]] && args+=(--allow-source-fallback)
  [[ "$AERO7_REPLACE_LAYOUT" == "yes" ]] && args+=(--replace-layout)
  [[ "$AERO7_REPLACE_LAYOUT" == "no" ]] && args+=(--keep-layout)
  [[ "$AERO7_INSTALL_WINXPLORER" == "yes" ]] && args+=(--install-winxplorer)
  [[ "$AERO7_INSTALL_SEVULET" == "yes" ]] && args+=(--install-sevulet)
  [[ -n "$AERO7_RESTART_STAGE" ]] && args+=(--restart-stage "$AERO7_RESTART_STAGE")
  local skipped
  for skipped in "${AERO7_SKIP_STAGES[@]}"; do
    args+=(--skip-stage "$skipped")
  done
  printf '%s\0' "${args[@]}"
}

if [[ -n "$AERO7_UI_DEMO" ]]; then
  ui_mode="$(aero7_select_ui_mode)"
  if [[ "$ui_mode" != "tui" ]]; then
    printf 'TUI unavailable: %s\n' "${ui_mode#plain:}" >&2
    exit 1
  fi
  aero7_launch_tui --demo "$AERO7_UI_DEMO"
  exit $?
fi

if [[ "$AERO7_BACKEND_RUN" != "1" ]]; then
  ui_mode="$(aero7_select_ui_mode)"
  if [[ "$AERO7_TUI" == "1" || "$ui_mode" == "tui" ]]; then
    if [[ "$ui_mode" != "tui" ]]; then
      printf 'TUI unavailable: %s\n' "${ui_mode#plain:}" >&2
      exit 1
    fi
    if ! aero7_dry_run; then
      aero7_tui_validate_sudo || aero7_die "Could not validate sudo credentials."
    fi
    aero7_tui_bootstrap_python_if_needed
    mapfile -d '' -t backend_args < <(build_backend_args)
    aero7_launch_tui --backend "$AERO7_PROJECT_ROOT/install.sh" "${backend_args[@]/#/--backend-arg=}"
    exit $?
  elif [[ "$AERO7_TUI_REQUESTED" == "1" ]]; then
    printf 'TUI unavailable: %s\n' "${ui_mode#plain:}" >&2
    exit 1
  fi
fi

aero7_logging_init install
aero7_refuse_root_install
AERO7_RECORD_WARNINGS=1
export AERO7_RECORD_WARNINGS

stage_files=(
  "$AERO7_STAGE_DIR/00-preflight.sh"
  "$AERO7_STAGE_DIR/10-backup.sh"
  "$AERO7_STAGE_DIR/20-system-update.sh"
  "$AERO7_STAGE_DIR/30-base-dependencies.sh"
  "$AERO7_STAGE_DIR/40-plasma-wayland.sh"
  "$AERO7_STAGE_DIR/50-yay.sh"
  "$AERO7_STAGE_DIR/55-binary-repository.sh"
  "$AERO7_STAGE_DIR/60-aeroshell.sh"
  "$AERO7_STAGE_DIR/70-aero-applications.sh"
  "$AERO7_STAGE_DIR/80-plasma-layout.sh"
  "$AERO7_STAGE_DIR/90-sddm.sh"
  "$AERO7_STAGE_DIR/100-plymouth.sh"
  "$AERO7_STAGE_DIR/110-fastfetch.sh"
  "$AERO7_STAGE_DIR/120-wine.sh"
  "$AERO7_STAGE_DIR/130-terminal-compat.sh"
  "$AERO7_STAGE_DIR/140-validation.sh"
)

stage_should_skip() {
  local stage="$1"
  local skipped
  for skipped in "${AERO7_SKIP_STAGES[@]}"; do
    [[ "$skipped" == "$stage" ]] && return 0
  done
  return 1
}

aero7_stage_complete_event() {
  local stage_id="$1"
  local status="${2:-complete}"
  if declare -F aero7_tui_backend >/dev/null 2>&1 &&
    aero7_tui_backend &&
    declare -F aero7_event_stage_complete >/dev/null 2>&1; then
    aero7_event_stage_complete "$stage_id" "$status" "$(aero7_stage_title "$stage_id")"
  fi
}

run_stage() {
  local file="$1"
  local stage_id
  local started_at elapsed
  stage_id="$(basename -- "$file" .sh)"
  AERO7_CURRENT_STAGE="$stage_id"
  export AERO7_CURRENT_STAGE
  started_at="$(date +%s)"

  unset -f stage_check stage_run stage_validate stage_rollback 2>/dev/null || true
  # shellcheck source=/dev/null
  source "$file"

  if stage_should_skip "$stage_id"; then
    aero7_skip "$stage_id skipped by option."
    aero7_stage_complete_event "$stage_id" skipped
    return 0
  fi

  if aero7_state_stage_complete "$stage_id" && [[ "$AERO7_RESTART_STAGE" != "$stage_id" ]]; then
    if stage_validate; then
      aero7_skip "$stage_id already complete."
      aero7_stage_complete_event "$stage_id" complete
      return 0
    fi
    aero7_warn "$stage_id was marked complete but validation failed; running it again."
  fi

  if ! stage_check; then
    aero7_skip "$stage_id check requested skip."
    aero7_stage_complete_event "$stage_id" skipped
    return 0
  fi

  aero7_state_set "current_stage" "$stage_id"
  if ! stage_run; then
    aero7_state_mark_stage_failed "$stage_id"
    stage_rollback || true
    return 1
  fi

  if ! stage_validate; then
    aero7_state_mark_stage_failed "$stage_id"
    stage_rollback || true
    return 1
  fi

  aero7_state_mark_stage_complete "$stage_id"
  elapsed=$(($(date +%s) - started_at))
  if [[ "$stage_id" != "140-validation" ]]; then
    aero7_ok "Completed in $(aero7_format_duration "$elapsed")"
  fi
  aero7_stage_complete_event "$stage_id" complete
}

aero7_title
aero7_summary
if ! aero7_non_interactive && [[ "$AERO7_ASSUME_YES" != "1" ]]; then
  aero7_confirm "Continue with Aero7-shell installation?" "no" || aero7_die "Installation cancelled."
fi

aero7_sudo_keepalive_start
trap 'aero7_sudo_keepalive_stop' EXIT
aero7_state_init
aero7_state_clear "warnings"

selected_stage_files=()
start_running=0
if [[ -z "$AERO7_RESTART_STAGE" ]]; then
  start_running=1
fi

for stage_file in "${stage_files[@]}"; do
  stage_id="$(basename -- "$stage_file" .sh)"
  if [[ "$start_running" -eq 0 ]]; then
    if [[ "$stage_id" == "$AERO7_RESTART_STAGE" ]]; then
      start_running=1
    else
      continue
    fi
  fi
  if stage_should_skip "$stage_id"; then
    continue
  fi
  selected_stage_files+=("$stage_file")
done

total="${#selected_stage_files[@]}"
if declare -F aero7_tui_backend >/dev/null 2>&1 &&
  aero7_tui_backend &&
  declare -F aero7_event_session_start >/dev/null 2>&1; then
  aero7_event_session_start "$total"
fi
index=0
for stage_file in "${selected_stage_files[@]}"; do
  index=$((index + 1))
  stage_id="$(basename -- "$stage_file" .sh)"
  aero7_stage_banner "$stage_id" "$index" "$total"
  run_stage "$stage_file" || aero7_die "Stage failed: $(aero7_stage_title "$stage_id")"
done

aero7_state_set "current_stage" "complete"
aero7_info "Installation flow completed. Review the final report and reboot when ready."
if declare -F aero7_tui_backend >/dev/null 2>&1 &&
  aero7_tui_backend &&
  declare -F aero7_event_session_complete >/dev/null 2>&1; then
  warnings="$(aero7_state_count_unique warnings 2>/dev/null || printf '0')"
  reboot_required=false
  reboot_prompt_enabled=false
  if [[ "$AERO7_NO_REBOOT" != "1" && "$(aero7_state_get reboot_recommended 2>/dev/null || printf 'no')" == "yes" ]]; then
    reboot_required=true
    if [[ "$(aero7_state_get reboot_prompt_allowed 2>/dev/null || printf 'no')" == "yes" ]]; then
      reboot_prompt_enabled=true
    fi
  fi
  aero7_event_session_complete "$warnings" "$reboot_required" "$reboot_prompt_enabled"
fi
