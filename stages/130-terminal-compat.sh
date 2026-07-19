#!/usr/bin/env bash

stage_check() {
  [[ "$(aero7_config_value InstallTerminalCompat)" != "false" ]]
}

stage_run() {
  aero7_install_management_commands
}

stage_validate() {
  [[ "${AERO7_DRY_RUN:-0}" == "1" ]] || [[ -x "$AERO7_SYSTEM_BIN_DIR/aero7" ]]
}

stage_rollback() {
  return 0
}

