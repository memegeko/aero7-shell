#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export AERO7_PROJECT_ROOT="$repo"

source "$repo/lib/common.sh"

fail() {
  printf 'test-recipes: %s\n' "$*" >&2
  exit 1
}

required=(
  AERO7_APP_ID
  AERO7_APP_NAME
  AERO7_APP_AUTHOR
  AERO7_APP_SUPPORTED_SESSION
  AERO7_APP_BUILD_SYSTEM
  AERO7_APP_INSTALL_KIND
  AERO7_APP_FATAL
  AERO7_APP_EXPERIMENTAL
  AERO7_APP_AVAILABLE
  AERO7_APP_SOURCE_URL
  AERO7_APP_BRANCH
  AERO7_APP_DEPENDENCIES
  AERO7_APP_BUILD_COMMAND
  AERO7_APP_INSTALL_COMMAND
  AERO7_APP_VALIDATE_COMMAND
  AERO7_APP_UNINSTALL_METADATA
  AERO7_APP_PLASMA6_COMPAT
  AERO7_APP_WAYLAND_COMPAT
  AERO7_APP_LICENSE
)

for recipe in "$repo"/recipes/*.sh; do
  bash -n "$recipe" || fail "syntax failed: $recipe"
  unset AERO7_APP_ID AERO7_APP_NAME AERO7_APP_AUTHOR AERO7_APP_SUPPORTED_SESSION
  unset AERO7_APP_BUILD_SYSTEM AERO7_APP_INSTALL_KIND AERO7_APP_FATAL
  unset AERO7_APP_EXPERIMENTAL AERO7_APP_AVAILABLE AERO7_APP_AUR_PACKAGE
  unset AERO7_APP_SOURCE_URL AERO7_APP_BRANCH AERO7_APP_BUILD_COMMAND
  unset AERO7_APP_INSTALL_COMMAND AERO7_APP_VALIDATE_COMMAND AERO7_APP_UNINSTALL_METADATA
  unset AERO7_APP_PLASMA6_COMPAT AERO7_APP_WAYLAND_COMPAT AERO7_APP_LICENSE
  # Recipes are metadata files selected dynamically by this test.
  # shellcheck source=/dev/null
  source "$recipe"
  for var in "${required[@]}"; do
    [[ -n "${!var:-}" ]] || fail "$(basename "$recipe") missing $var"
  done
  case "$AERO7_APP_SUPPORTED_SESSION" in
    wayland|any) ;;
    *) fail "$(basename "$recipe") is not Wayland-compatible" ;;
  esac
  if [[ "$AERO7_APP_INSTALL_KIND" == "aur" ]]; then
    [[ -n "${AERO7_APP_AUR_PACKAGE:-}" ]] || fail "$(basename "$recipe") lacks AUR package"
  fi
  if [[ "$AERO7_APP_AVAILABLE" == "no" ]]; then
    [[ "$AERO7_APP_BUILD_COMMAND" == disabled* ]] || fail "$(basename "$recipe") disabled recipe has executable-looking build command"
    [[ -n "${AERO7_APP_REASON:-}" ]] || fail "$(basename "$recipe") disabled recipe lacks reason"
  fi
done

printf 'test-recipes: ok\n'
