#!/usr/bin/env bash

stage_check() {
  aero7_binary_packages_preferred
}

stage_run() {
  aero7_binary_repo_prepare
}

stage_validate() {
  if [[ "${AERO7_PACKAGE_MODE:-auto}" == "source" ]]; then
    return 0
  fi
  if [[ "$(aero7_state_get binary_repo_ready 2>/dev/null || printf no)" == "yes" ]]; then
    return 0
  fi
  [[ "${AERO7_ALLOW_SOURCE_FALLBACK:-0}" == "1" ]]
}

stage_rollback() {
  return 0
}
