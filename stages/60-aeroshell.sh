#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_warn "Installing Wayland AeroThemePlasma packages. X11 Aero packages remain prohibited."
  aero7_install_aero_packages
}

stage_validate() {
  aero7_validate_no_x11_packages_configured || return 1
  aero7_dry_run && return 0
  aero7_configured_pacman_packages_installed "$AERO7_CONFIG_DIR/aur-packages.conf"
}

stage_rollback() {
  return 0
}
