#!/usr/bin/env bash

if [[ -n "${AERO7_SYSTEMD_LOADED:-}" ]]; then
  return 0
fi
AERO7_SYSTEMD_LOADED=1

aero7_systemctl_enable() {
  local unit="$1"
  if aero7_dry_run; then
    aero7_info "Would enable $unit."
    return 0
  fi
  aero7_sudo_run systemctl enable "$unit"
}

aero7_systemctl_is_enabled() {
  local unit="$1"
  systemctl is-enabled "$unit" >/dev/null 2>&1
}

aero7_systemd_unit_exists() {
  local unit="$1"
  systemctl list-unit-files "$unit" --no-legend 2>/dev/null | awk '{ print $1 }' | grep -Fxq "$unit"
}

aero7_enable_core_services() {
  if aero7_have systemctl || aero7_dry_run; then
    aero7_systemctl_enable NetworkManager.service
    aero7_systemctl_enable sddm.service
  else
    aero7_warn "systemctl is unavailable; cannot enable services."
    return 1
  fi
}

aero7_validate_core_services() {
  local unit failed=0
  if aero7_dry_run; then
    return 0
  fi
  if ! aero7_have systemctl; then
    aero7_warn "systemctl is unavailable; cannot validate core services."
    return 1
  fi

  for unit in NetworkManager.service sddm.service; do
    if ! aero7_systemd_unit_exists "$unit"; then
      aero7_warn "Required systemd unit is missing despite saved state: $unit"
      failed=1
      continue
    fi
    if ! aero7_systemctl_is_enabled "$unit"; then
      aero7_warn "Required systemd unit is not enabled despite saved state: $unit"
      failed=1
    fi
  done
  return "$failed"
}
