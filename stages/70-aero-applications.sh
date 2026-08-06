#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  # Image mode already installed and verified the signed Aero7 package
  # allowlist before the account existed. Do not re-enter package/AUR logic at
  # first boot; this stage is retained so the new user's launchers are branded.
  if [[ "${AERO7_IMAGE_MODE:-0}" != "1" ]]; then
    aero7_apps_install_defaults
  fi
  aero7_install_application_branding
}

stage_validate() {
  return 0
}

stage_rollback() {
  return 0
}
