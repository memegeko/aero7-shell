#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_create_backup
}

stage_validate() {
  [[ -n "$(aero7_state_get backup_id 2>/dev/null || true)" ]]
}

stage_rollback() {
  return 0
}

