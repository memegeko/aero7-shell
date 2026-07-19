#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_validate_no_x11_packages_configured || aero7_die "Aero7-shell install lists include prohibited X11 packages."
  aero7_enable_core_services
}

stage_validate() {
  local failed=0
  aero7_validate_no_x11_packages_configured || failed=1
  aero7_validate_core_services || failed=1
  return "$failed"
}

stage_rollback() {
  return 0
}
