#!/usr/bin/env bash

aero7_select_plymouth_theme() {
  local themes candidate
  themes="$(plymouth-set-default-theme --list 2>/dev/null || true)"
  for candidate in aero7-shell spinner bgrt fade-in; do
    if grep -Fxq "$candidate" <<<"$themes"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

stage_check() {
  [[ "$(aero7_config_value InstallPlymouth)" != "false" ]]
}

stage_run() {
  aero7_pacman_install_needed plymouth
  aero7_install_plymouth_theme

  if aero7_dry_run; then
    aero7_info "Would select the Aero7-shell Plymouth theme, hold it for five seconds, and configure initramfs and bootloader."
    aero7_configure_plymouth_visibility
    aero7_configure_initramfs_for_plymouth
    aero7_configure_bootloader_for_plymouth
    return 0
  fi

  if aero7_have plymouth-set-default-theme; then
    local theme
    theme="$(aero7_select_plymouth_theme || true)"
    if [[ -n "$theme" ]]; then
      aero7_sudo_run plymouth-set-default-theme "$theme"
      aero7_state_set "plymouth_theme" "$theme"
    else
      aero7_warn "No safe distribution-provided Plymouth theme was found; leaving the current Plymouth theme unchanged."
      aero7_state_set "plymouth_theme" "system-default"
    fi
  else
    aero7_die "plymouth-set-default-theme is unavailable."
  fi

  aero7_configure_plymouth_visibility
  aero7_configure_initramfs_for_plymouth
  aero7_configure_bootloader_for_plymouth
}

stage_validate() {
  [[ "${AERO7_DRY_RUN:-0}" == "1" ]] && return 0
  aero7_have plymouth-set-default-theme || return 1
  aero7_validate_installed_plymouth_theme || return 1
  [[ "$(plymouth-set-default-theme 2>/dev/null)" == "aero7-shell" ]] || return 1
  aero7_plymouth_visibility_configured || return 1
  aero7_initramfs_config_has_plymouth || return 1
  aero7_bootloader_config_has_kernel_params quiet splash || return 1
  if aero7_have lsinitcpio; then
    aero7_initramfs_image_contains_plymouth || return 1
  fi
}

stage_rollback() {
  aero7_warn "Plymouth rollback is handled through aero7 restore after backup selection."
}
