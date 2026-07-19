#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  aero7_require_arch_or_dry_run
  [[ "$AERO7_SESSION" == "wayland" ]] || aero7_die "Only Wayland is supported."

  if [[ "$(aero7_config_value Session)" == "x11" ]]; then
    aero7_die "Aero7-shell version 1 rejects Session=x11. Plasma Wayland is the only supported session."
  fi

  local tool
  for tool in bash curl sudo; do
    if ! aero7_have "$tool" && ! aero7_dry_run; then
      aero7_die "Required tool missing: $tool"
    fi
  done

  aero7_state_set "installer_version" "$AERO7_VERSION"
  aero7_state_set "original_desktop_session" "${XDG_SESSION_TYPE:-unknown}"
  aero7_state_record_option "replace_layout" "$AERO7_REPLACE_LAYOUT"
  aero7_state_record_option "install_winxplorer" "$AERO7_INSTALL_WINXPLORER"
  aero7_state_record_option "install_sevulet" "$AERO7_INSTALL_SEVULET"

  aero7_warn "Some Aero effects may be less complete on Wayland than on X11. Aero7-shell will not install an X11 session."
}

stage_validate() {
  [[ "$(aero7_state_get installer_version 2>/dev/null || true)" == "$AERO7_VERSION" ]]
}

stage_rollback() {
  return 0
}
