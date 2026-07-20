#!/usr/bin/env bash

if [[ -n "${AERO7_REPOSITORY_KEY_LOADED:-}" ]]; then
  return 0
fi
AERO7_REPOSITORY_KEY_LOADED=1

aero7_repository_key_configured() {
  [[ -n "${AERO7_BINARY_REPOSITORY_FINGERPRINT:-}" ]] &&
    [[ "${AERO7_BINARY_REPOSITORY_FINGERPRINT:-}" != "MANUAL_ACTION_REQUIRED" ]] &&
    [[ "${AERO7_BINARY_REPOSITORY_FINGERPRINT:-}" != "MANUAL ACTION REQUIRED" ]]
}

aero7_repository_key_normalize_fingerprint() {
  printf '%s\n' "$1" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]'
}

aero7_repository_key_file_fingerprint() {
  local key_file="$1"
  [[ -r "$key_file" ]] || return 1
  gpg --with-colons --import-options show-only --import "$key_file" 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }'
}

aero7_repository_key_verify_file() {
  local key_file="${1:-$AERO7_BINARY_REPOSITORY_KEY_FILE}"
  local expected actual
  aero7_repository_key_configured || {
    aero7_warn "Aero7 repository signing fingerprint is not configured yet."
    return 1
  }
  [[ -r "$key_file" ]] || {
    aero7_warn "Aero7 repository public key is missing: $key_file"
    return 1
  }
  expected="$(aero7_repository_key_normalize_fingerprint "$AERO7_BINARY_REPOSITORY_FINGERPRINT")"
  actual="$(aero7_repository_key_file_fingerprint "$key_file" || true)"
  actual="$(aero7_repository_key_normalize_fingerprint "$actual")"
  if [[ -z "$actual" || "$actual" != "$expected" ]]; then
    aero7_warn "Aero7 repository key fingerprint mismatch."
    return 1
  fi
  return 0
}

aero7_repository_key_import_to_pacman() {
  local key_file="${1:-$AERO7_BINARY_REPOSITORY_KEY_FILE}"
  aero7_repository_key_verify_file "$key_file" || return 1
  if aero7_dry_run; then
    aero7_detail "Would import and locally sign Aero7 repository key."
    return 0
  fi
  aero7_sudo_run pacman-key --add "$key_file"
  aero7_sudo_run pacman-key --finger "$AERO7_BINARY_REPOSITORY_FINGERPRINT"
  aero7_sudo_run pacman-key --lsign-key "$AERO7_BINARY_REPOSITORY_FINGERPRINT"
}
