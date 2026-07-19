#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  if ! aero7_validate_plasma_wayland_session && ! aero7_dry_run; then
    aero7_die "No Plasma Wayland session file found under /usr/share/wayland-sessions."
  fi
  aero7_configure_sddm
}

stage_validate() {
  [[ -f /etc/sddm.conf.d/aero7-shell.conf || "${AERO7_DRY_RUN:-0}" == "1" ]] || return 1
  aero7_dry_run || aero7_validate_plasma_wayland_session
}

stage_rollback() {
  return 0
}
