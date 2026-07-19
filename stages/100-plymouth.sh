#!/usr/bin/env bash

aero7_select_plymouth_theme() {
  local themes
  themes="$(plymouth-set-default-theme --list 2>/dev/null || true)"
  awk '
    $0 == "bgrt" || $0 == "spinner" || $0 == "fade-in" {
      print
      exit
    }
  ' <<<"$themes"
}

stage_check() {
  [[ "$(aero7_config_value InstallPlymouth)" != "false" ]]
}

stage_run() {
  aero7_pacman_install_needed plymouth

  if aero7_dry_run; then
    aero7_info "Would enable Plymouth with an installed distribution theme and configure initramfs and bootloader."
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

  aero7_configure_initramfs_for_plymouth
  aero7_configure_bootloader_for_plymouth
}

stage_validate() {
  [[ "${AERO7_DRY_RUN:-0}" == "1" ]] || aero7_have plymouth-set-default-theme
}

stage_rollback() {
  aero7_warn "Plymouth rollback is handled through aero7 restore after backup selection."
}
