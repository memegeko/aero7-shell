#!/usr/bin/env bash

stage_check() {
  [[ "$(aero7_config_value InstallFastfetch)" != "false" ]]
}

stage_run() {
  aero7_pacman_install_needed fastfetch

  local user_config_dir="$AERO7_HOME/.config/fastfetch"
  local aero_config="$user_config_dir/aero7.jsonc"
  local default_config="$user_config_dir/config.jsonc"

  if aero7_dry_run; then
    aero7_info "Would install Aero7 Fastfetch config to $aero_config."
    return 0
  fi

  aero7_user_run install -d -m 0755 "$user_config_dir"
  aero7_user_run install -m 0644 "$AERO7_ROOT/assets/fastfetch/aero7.jsonc" "$aero_config"
  aero7_state_append "modified_user_files" "$aero_config"
  if [[ ! -e "$default_config" ]]; then
    aero7_user_run ln -s "aero7.jsonc" "$default_config"
    aero7_state_append "modified_user_files" "$default_config"
  else
    aero7_warn "Existing Fastfetch config preserved. Use aero7 fastfetch to run the Aero7 profile."
  fi
}

stage_validate() {
  [[ "${AERO7_DRY_RUN:-0}" == "1" ]] || [[ -f "$AERO7_HOME/.config/fastfetch/aero7.jsonc" ]]
}

stage_rollback() {
  return 0
}
