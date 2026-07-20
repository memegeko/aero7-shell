#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  local doctor_failed=0
  aero7_state_set "reboot_prompt_allowed" "no"
  aero7_doctor || doctor_failed=1
  if [[ "$doctor_failed" -eq 1 ]]; then
    aero7_warn "Doctor reported warnings or failures; review before rebooting."
  fi
  aero7_final_report
  if [[ "${AERO7_NO_REBOOT:-0}" == "1" ]]; then
    aero7_info "Reboot prompt skipped by --no-reboot."
    return 0
  fi
  if [[ "$doctor_failed" -eq 1 ]]; then
    aero7_warn "Reboot prompt suppressed because final validation reported failures."
    return 0
  fi
  if [[ "$(aero7_state_get reboot_recommended 2>/dev/null || true)" == "yes" ]]; then
    if declare -F aero7_tui_backend >/dev/null 2>&1 && aero7_tui_backend; then
      aero7_state_set "reboot_prompt_allowed" "yes"
      aero7_info "Reboot prompt will be shown by the full-screen installer."
      return 0
    fi
    if aero7_confirm "Reboot now?" "no"; then
      aero7_sudo_run systemctl reboot
    else
      aero7_info "Reboot declined. Reboot manually when ready."
    fi
  fi
}

stage_validate() {
  return 0
}

stage_rollback() {
  return 0
}
