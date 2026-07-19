#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_pacman_system_update
}

stage_validate() {
  return 0
}

stage_rollback() {
  return 0
}

