#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_warn "Installing Wayland AeroThemePlasma packages. X11 Aero packages remain prohibited."
  aero7_install_configured_aur_packages
}

stage_validate() {
  aero7_validate_no_x11_packages_configured
}

stage_rollback() {
  return 0
}
