#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_install_configured_pacman_packages
}

stage_validate() {
  if aero7_dry_run; then
    return 0
  fi
  aero7_configured_pacman_packages_installed
}

stage_rollback() {
  return 0
}
