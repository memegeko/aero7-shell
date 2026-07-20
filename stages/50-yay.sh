#!/usr/bin/env bash

stage_check() {
  aero7_source_build_may_be_needed
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
