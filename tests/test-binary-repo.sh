#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'test-binary-repo: %s\n' "$*" >&2
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
export AERO7_USER_STATE_DIR="$tmp/state"
export AERO7_LOG_DIR="$tmp/logs"
export AERO7_DRY_RUN=1
export AERO7_NON_INTERACTIVE=1
export AERO7_ASSUME_YES=1
export TERM=dumb
mkdir -p "$AERO7_HOME"

source "$repo/lib/common.sh"
source "$repo/lib/logging.sh"
source "$repo/lib/ui.sh"
source "$repo/lib/prompts.sh"
source "$repo/lib/state.sh"
source "$repo/lib/packages.sh"
source "$repo/lib/repository-key.sh"
source "$repo/lib/binary-repo.sh"
source "$repo/lib/aur.sh"

aero7_init_paths
aero7_logging_init binary-repo-test

export AERO7_BINARY_REPOSITORY_FINGERPRINT="00112233445566778899AABBCCDDEEFF00112233"
key_file="$tmp/aero7-repository.asc"
printf 'public key placeholder\n' >"$key_file"
export AERO7_BINARY_REPOSITORY_KEY_FILE="$key_file"

gpg() {
  printf 'fpr:::::::::00112233445566778899AABBCCDDEEFF00112233:\n'
}
aero7_repository_key_verify_file "$key_file" || fail "matching repository key fingerprint was rejected"

export AERO7_BINARY_REPOSITORY_FINGERPRINT="FFEEDDCCBBAA99887766554433221100FFEEDDCC"
if aero7_repository_key_verify_file "$key_file" >/dev/null 2>&1; then
  fail "mismatched repository key fingerprint was accepted"
fi

export AERO7_DRY_RUN=0
export AERO7_BINARY_REPOSITORY_FINGERPRINT="00112233445566778899AABBCCDDEEFF00112233"
export AERO7_TEST_ROOT="$tmp/test-root"
export AERO7_PACMAN_CONF="$tmp/pacman.conf"
export AERO7_PACMAN_AERO7_CONF="$tmp/aero7.conf"
export AERO7_PACMAN_AERO7_MIRRORLIST="$tmp/aero7-mirrorlist"
printf '[options]\nArchitecture = auto\n' >"$AERO7_PACMAN_CONF"
aero7_repository_key_import_to_pacman() { return 0; }
aero7_binary_repo_enable
aero7_binary_repo_enable
[[ "$(grep -c "Include = $AERO7_PACMAN_AERO7_CONF" "$AERO7_PACMAN_CONF")" -eq 1 ]] || fail "repository include was not idempotent"
grep -q 'SigLevel = Required DatabaseRequired' "$AERO7_PACMAN_AERO7_CONF" || fail "repository config did not require signatures"

export AERO7_DRY_RUN=1
unset AERO7_TEST_ROOT
export AERO7_STATE_ROOT_OVERRIDE="$tmp/origin-state"
aero7_state_init
aero7_binary_repo_install_packages >/dev/null
[[ "$(aero7_state_get aero_packages_origin)" == "binary" ]] || fail "binary install did not record binary origin"
[[ "$(aero7_state_unique_file package_origin | wc -l | tr -d ' ')" -eq 8 ]] || fail "binary install did not record all package origins"

export AERO7_NON_INTERACTIVE=1
export AERO7_ALLOW_SOURCE_FALLBACK=0
if aero7_source_fallback_allowed_or_prompt; then
  fail "noninteractive fallback was allowed without explicit flag"
fi
export AERO7_ALLOW_SOURCE_FALLBACK=1
aero7_source_fallback_allowed_or_prompt || fail "explicit source fallback flag was ignored"

printf 'test-binary-repo: ok\n'
