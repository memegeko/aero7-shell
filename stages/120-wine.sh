#!/usr/bin/env bash

stage_check() {
  [[ "$(aero7_config_value InstallWine)" != "false" ]]
}

stage_run() {
  aero7_pacman_install_needed wine wine-mono wine-gecko xdg-utils shared-mime-info desktop-file-utils
  aero7_state_set "wine_integration" "enabled"
}

stage_validate() {
  [[ "${AERO7_DRY_RUN:-0}" == "1" ]] || aero7_have wine
}

stage_rollback() {
  return 0
}

