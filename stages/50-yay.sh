#!/usr/bin/env bash

stage_check() {
  aero7_source_build_may_be_needed || aero7_apps_may_need_aur
}

stage_run() {
  aero7_install_yay
}

stage_validate() {
  aero7_dry_run || aero7_yay_available
}

stage_rollback() {
  return 0
}
