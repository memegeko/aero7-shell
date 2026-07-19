#!/usr/bin/env bash

stage_check() {
  return 0
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

