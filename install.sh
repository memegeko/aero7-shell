#!/usr/bin/env bash
set -Eeuo pipefail

AERO7_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export AERO7_PROJECT_ROOT

# shellcheck source=lib/common.sh
source "$AERO7_PROJECT_ROOT/lib/common.sh"

AERO7_ASSUME_YES=1
AERO7_NON_INTERACTIVE=1
AERO7_DRY_RUN=0
AERO7_DEBUG="${AERO7_DEBUG:-0}"
AERO7_NO_COLOR="${AERO7_NO_COLOR:-0}"
AERO7_PLAIN="${AERO7_PLAIN:-0}"
AERO7_QUIET="${AERO7_QUIET:-0}"
AERO7_RESUME=0
AERO7_NO_REBOOT=0
AERO7_REPLACE_LAYOUT="ask"
AERO7_INSTALL_WINXPLORER="ask"
AERO7_INSTALL_SEVULET="ask"
AERO7_RESTART_STAGE=""
AERO7_SKIP_STAGES=()
AERO7_REBOOT="ask"

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
  --resume               Resume from saved state
  --restart-stage STAGE  Restart from a specific stage id
  --skip-stage STAGE     Skip a specific stage id
  --no-reboot            Never prompt to reboot
  --replace-layout       Apply the full Aero7-shell Plasma layout
  --keep-layout          Keep current Plasma layout
  --install-winxplorer   Include optional WinXplorer recipe if available
  --install-sevulet      Include optional Sevulet recipe if available
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --version) printf '%s\n' "$AERO7_VERSION"; exit 0 ;;
    --yes) AERO7_ASSUME_YES=1 ;;
    --non-interactive) AERO7_NON_INTERACTIVE=1 ;;
    --interactive) AERO7_ASSUME_YES=0; AERO7_NON_INTERACTIVE=0 ;;
    --dry-run) AERO7_DRY_RUN=1 ;;
    --no-color) AERO7_NO_COLOR=1 ;;
    --plain) AERO7_PLAIN=1 ;;
    --quiet) AERO7_QUIET=1 ;;
    --debug) AERO7_DEBUG=1 ;;
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
export AERO7_NO_COLOR AERO7_PLAIN AERO7_QUIET
export AERO7_RESUME AERO7_NO_REBOOT AERO7_REPLACE_LAYOUT
export AERO7_INSTALL_WINXPLORER AERO7_INSTALL_SEVULET AERO7_REBOOT

if [[ "$AERO7_DEBUG" == "1" ]]; then
  export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}:stage=${AERO7_CURRENT_STAGE:-startup}: '
  set -x
fi

# shellcheck source=lib/logging.sh
source "$AERO7_PROJECT_ROOT/lib/logging.sh"
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
    return 0
  fi

  if aero7_state_stage_complete "$stage_id" && [[ "$AERO7_RESTART_STAGE" != "$stage_id" ]]; then
    if stage_validate; then
      aero7_skip "$stage_id already complete."
      return 0
    fi
    aero7_warn "$stage_id was marked complete but validation failed; running it again."
  fi

  if ! stage_check; then
    aero7_skip "$stage_id check requested skip."
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
  aero7_ok "Completed in $(aero7_format_duration "$elapsed")"
}

aero7_title
aero7_summary
if ! aero7_non_interactive && [[ "$AERO7_ASSUME_YES" != "1" ]]; then
  aero7_confirm "Continue with Aero7-shell installation?" "no" || aero7_die "Installation cancelled."
fi

aero7_sudo_keepalive_start
trap 'aero7_sudo_keepalive_stop' EXIT
aero7_state_init

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
index=0
for stage_file in "${selected_stage_files[@]}"; do
  index=$((index + 1))
  stage_id="$(basename -- "$stage_file" .sh)"
  aero7_stage_banner "$stage_id" "$index" "$total"
  run_stage "$stage_file" || aero7_die "Stage failed: $(aero7_stage_title "$stage_id")"
done

aero7_state_set "current_stage" "complete"
aero7_detail "Installation flow completed. Review the final report and reboot when ready."
