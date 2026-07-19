#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'test-ui: %s\n' "$*" >&2
  exit 1
}

tmp="$(mktemp -d)"
cleanup() {
  rm -rf -- "$tmp"
}
trap cleanup EXIT

export AERO7_PROJECT_ROOT="$repo"
export AERO7_USER="$(id -un)"
export AERO7_HOME="$tmp/home"
export AERO7_LOG_DIR="$tmp/logs"
export AERO7_DRY_RUN=0
export AERO7_DEBUG=0
export AERO7_PLAIN=1
export TERM=dumb
mkdir -p "$AERO7_HOME"

source "$repo/lib/common.sh"
source "$repo/lib/logging.sh"
source "$repo/lib/ui.sh"
source "$repo/lib/prompts.sh"

aero7_logging_init ui

normal_output="$(aero7_run bash -lc 'printf "normal-hidden\n"' 2>&1)"
[[ "$normal_output" != *"normal-hidden"* ]] || fail "normal mode leaked successful command output"
grep -q 'normal-hidden' "$AERO7_LOG_FILE" || fail "normal mode did not log captured command output"

set +e
failure_output="$(aero7_run bash -lc 'printf "failure-hidden-1\nfailure-hidden-2\n"; exit 7' 2>&1)"
failure_code=$?
set -e
[[ "$failure_code" -eq 7 ]] || fail "command runner swallowed failure exit code"
[[ "$failure_output" == *"[FAIL] Command failed: bash"* ]] || fail "failure output did not include concise failure"
[[ "$failure_output" == *"Last output:"* ]] || fail "failure output did not include excerpt heading"
[[ "$failure_output" == *"failure-hidden-2"* ]] || fail "failure output did not include useful tail"
grep -q 'failure-hidden-1' "$AERO7_LOG_FILE" || fail "failure output was not saved to log"

AERO7_DEBUG=1
export AERO7_DEBUG
debug_output="$(aero7_run bash -lc 'printf "debug-visible\n"' 2>&1)"
[[ "$debug_output" == *"+ bash -lc"* ]] || fail "debug mode did not show command before execution"
[[ "$debug_output" == *"debug-visible"* ]] || fail "debug mode did not stream command output"
AERO7_DEBUG=0
export AERO7_DEBUG

layout_prompt_err="$tmp/layout-prompt.err"
layout_choice="$(printf '2\n' | aero7_prompt_layout_choice 2>"$layout_prompt_err")"
[[ "$layout_choice" == "keep" ]] || fail "layout prompt did not return only the selected value"
grep -q 'Plasma layout' "$layout_prompt_err" || fail "layout prompt did not render user-facing text on stderr"

install_dir="$tmp/install"
mkdir -p "$install_dir"
AERO7_USER_STATE_DIR="$install_dir/state" \
AERO7_LOG_DIR="$install_dir/logs" \
AERO7_LOG_FILE= \
TERM=dumb \
"$repo/install.sh" --dry-run --non-interactive --no-reboot --plain \
  >"$install_dir/plain.out" 2>"$install_dir/plain.err" || fail "plain dry-run failed"

if grep -q $'\033' "$install_dir/plain.out" "$install_dir/plain.err"; then
  fail "plain dry-run emitted ANSI color"
fi
if grep -q $'\r' "$install_dir/plain.out" "$install_dir/plain.err"; then
  fail "plain dry-run emitted carriage-return animation artifacts"
fi
if grep -q $'\033\\[?25' "$install_dir/plain.out" "$install_dir/plain.err"; then
  fail "plain dry-run emitted cursor visibility control"
fi
grep -Eq '\[ +1/15 \] Checking system' "$install_dir/plain.out" || fail "plain dry-run missed stage numbering"
grep -q 'Installation completed' "$install_dir/plain.out" || fail "plain dry-run missed final summary"
grep -q '^  Warnings' "$install_dir/plain.out" || fail "plain dry-run missed warning count"

default_dir="$install_dir/default"
mkdir -p "$default_dir"
AERO7_USER_STATE_DIR="$default_dir/state" \
AERO7_LOG_DIR="$default_dir/logs" \
AERO7_LOG_FILE= \
TERM=dumb \
"$repo/install.sh" --dry-run --no-reboot --plain \
  >"$default_dir/default.out" 2>"$default_dir/default.err" || fail "default dry-run failed"
! grep -q 'Continue with Aero7-shell installation?' "$default_dir/default.out" || fail "default install prompted for confirmation"
grep -q 'sudo pacman -Syu --noconfirm' "$default_dir/default.out" || fail "default install did not assume yes for pacman"
grep -q '^kept$' "$default_dir/state/dry-run/state/options/layout" || fail "default install did not use noninteractive layout choice"

AERO7_USER_STATE_DIR="$install_dir/quiet-state" \
AERO7_LOG_DIR="$install_dir/quiet-logs" \
AERO7_LOG_FILE= \
TERM=dumb \
"$repo/install.sh" --dry-run --non-interactive --no-reboot --plain --quiet \
  >"$install_dir/quiet.out" 2>"$install_dir/quiet.err" || fail "quiet dry-run failed"

grep -Eq '\[ +1/15 \] Checking system' "$install_dir/quiet.out" || fail "quiet dry-run missed stage heading"
! grep -q 'Would install:' "$install_dir/quiet.out" || fail "quiet dry-run showed routine details"
grep -q 'Installation completed' "$install_dir/quiet.out" || fail "quiet dry-run missed final summary"

debug_dir="$install_dir/debug"
mkdir -p "$debug_dir"
AERO7_USER_STATE_DIR="$debug_dir/state" \
AERO7_LOG_DIR="$debug_dir/logs" \
AERO7_LOG_FILE= \
TERM=dumb \
"$repo/install.sh" --dry-run --non-interactive --no-reboot --plain --debug \
  >"$debug_dir/debug.out" 2>"$debug_dir/debug.err" || fail "debug dry-run failed"
grep -q 'stage=' "$debug_dir/debug.err" || fail "debug dry-run did not include stage diagnostics"
grep -q 'DRY-RUN command stage=' "$debug_dir"/logs/install-*.log || fail "debug dry-run did not log command diagnostics"

no_color_dir="$install_dir/no-color"
mkdir -p "$no_color_dir"
NO_COLOR=1 \
AERO7_USER_STATE_DIR="$no_color_dir/state" \
AERO7_LOG_DIR="$no_color_dir/logs" \
AERO7_LOG_FILE= \
TERM=xterm-256color \
"$repo/install.sh" --dry-run --non-interactive --no-reboot --no-color \
  >"$no_color_dir/no-color.out" 2>"$no_color_dir/no-color.err" || fail "NO_COLOR dry-run failed"
if grep -q $'\033' "$no_color_dir/no-color.out" "$no_color_dir/no-color.err"; then
  fail "NO_COLOR dry-run emitted ANSI color"
fi

ci_dir="$install_dir/ci"
mkdir -p "$ci_dir"
CI=true \
AERO7_USER_STATE_DIR="$ci_dir/state" \
AERO7_LOG_DIR="$ci_dir/logs" \
AERO7_LOG_FILE= \
TERM=xterm-256color \
"$repo/install.sh" --dry-run --non-interactive --no-reboot \
  >"$ci_dir/ci.out" 2>"$ci_dir/ci.err" || fail "CI dry-run failed"
if grep -q $'\033' "$ci_dir/ci.out" "$ci_dir/ci.err"; then
  fail "CI dry-run emitted ANSI color"
fi
if grep -q $'\r' "$ci_dir/ci.out" "$ci_dir/ci.err"; then
  fail "CI dry-run emitted animation artifacts"
fi

mgmt_dir="$tmp/management"
mkdir -p "$mgmt_dir/home" "$mgmt_dir/logs" "$mgmt_dir/state"
printf 'old\n' >"$mgmt_dir/logs/install-old.log"
printf 'new\n' >"$mgmt_dir/logs/install-new.log"
touch -d '2026-07-18 10:00:00' "$mgmt_dir/logs/install-old.log"
touch -d '2026-07-18 11:00:00' "$mgmt_dir/logs/install-new.log"
latest_log="$(
  AERO7_HOME="$mgmt_dir/home" \
  AERO7_LOG_DIR="$mgmt_dir/logs" \
  AERO7_USER_STATE_DIR="$mgmt_dir/state" \
  TERM=dumb \
  "$repo/commands/aero7" --plain logs --latest
)"
[[ "$latest_log" == "$mgmt_dir/logs/install-new.log" ]] || fail "aero7 logs --latest returned wrong log: $latest_log"
if compgen -G "$mgmt_dir/logs/aero7-*.log" >/dev/null; then
  fail "aero7 logs --latest created a fresh management log"
fi

status_output="$(
  env -u AERO7_PROJECT_ROOT \
    AERO7_HOME="$mgmt_dir/home" \
    AERO7_LOG_DIR="$mgmt_dir/status-logs" \
    AERO7_LOG_FILE= \
    AERO7_USER_STATE_DIR="$mgmt_dir/state" \
    TERM=dumb \
    "$repo/commands/aero7" --plain status
)"
[[ "$status_output" == *"Aero7-shell Status"* ]] || fail "aero7 status missed title"
[[ "$status_output" == *"Warnings"* ]] || fail "aero7 status missed warning count"

apps_output="$(
  env -u AERO7_PROJECT_ROOT \
    AERO7_HOME="$mgmt_dir/home" \
    AERO7_LOG_DIR="$mgmt_dir/apps-logs" \
    AERO7_LOG_FILE= \
    AERO7_USER_STATE_DIR="$mgmt_dir/state" \
    TERM=dumb \
    "$repo/commands/aero7" --plain apps status
)"
[[ "$apps_output" == *"Aero7-shell Applications"* ]] || fail "aero7 apps status missed title"
[[ "$apps_output" == *"Result"* ]] || fail "aero7 apps status missed result"

plymouth_output="$(
  env -u AERO7_PROJECT_ROOT \
    AERO7_HOME="$mgmt_dir/home" \
    AERO7_LOG_DIR="$mgmt_dir/plymouth-logs" \
    AERO7_LOG_FILE= \
    AERO7_USER_STATE_DIR="$mgmt_dir/state" \
    TERM=dumb \
    "$repo/commands/aero7" --plain plymouth status
)"
[[ "$plymouth_output" == *"Aero7-shell Plymouth"* ]] || fail "aero7 plymouth status missed title"
[[ "$plymouth_output" == *"Bootloader"* ]] || fail "aero7 plymouth status missed bootloader"

printf 'test-ui: ok\n'
