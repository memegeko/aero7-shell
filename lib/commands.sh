#!/usr/bin/env bash

if [[ -n "${AERO7_COMMANDS_LOADED:-}" ]]; then
  return 0
fi
AERO7_COMMANDS_LOADED=1

aero7_install_management_commands() {
  if aero7_dry_run; then
    aero7_info "Would install runtime files to $AERO7_SYSTEM_LIB_DIR and assets to $AERO7_ASSET_DIR."
  else
    aero7_sudo_run install -d -m 0755 "$AERO7_SYSTEM_LIB_DIR" "$AERO7_ASSET_DIR"
    aero7_sudo_run cp -a "$AERO7_ROOT/lib" "$AERO7_SYSTEM_LIB_DIR/"
    aero7_sudo_run cp -a "$AERO7_ROOT/config" "$AERO7_SYSTEM_LIB_DIR/"
    aero7_sudo_run cp -a "$AERO7_ROOT/recipes" "$AERO7_SYSTEM_LIB_DIR/"
    aero7_sudo_run cp -a "$AERO7_ROOT/modules" "$AERO7_SYSTEM_LIB_DIR/"
    aero7_sudo_run install -m 0755 "$AERO7_ROOT/update.sh" "$AERO7_SYSTEM_LIB_DIR/update.sh"
    aero7_sudo_run install -m 0755 "$AERO7_ROOT/uninstall.sh" "$AERO7_SYSTEM_LIB_DIR/uninstall.sh"
    aero7_install_assets
  fi

  local command
  for command in aero7 aero7-dir aero7-ipconfig aero7-systeminfo aero7-winver; do
    aero7_install_root_file "$AERO7_ROOT/commands/$command" "$AERO7_SYSTEM_BIN_DIR/$command" 0755
  done

  local shell_dir="$AERO7_HOME/.config/aero7-shell"
  local shell_file="$shell_dir/shell.sh"
  if aero7_dry_run; then
    aero7_info "Would install shell compatibility file at $shell_file."
    return 0
  fi
  aero7_user_run install -d -m 0755 "$shell_dir"
  if [[ ! -f "$shell_file" ]] || ! grep -q 'aero7-dir' "$shell_file"; then
    {
      printf '# Aero7-shell compatibility helpers\n'
      printf 'alias cls=clear\n'
      printf 'dir() { aero7-dir "$@"; }\n'
      printf 'ipconfig() { aero7-ipconfig "$@"; }\n'
      printf 'systeminfo() { aero7-systeminfo "$@"; }\n'
      printf 'winver() { aero7-winver "$@"; }\n'
    } >"$shell_file"
    chown "$AERO7_USER:$AERO7_USER" "$shell_file" 2>/dev/null || true
    aero7_state_append "modified_user_files" "$shell_file"
  fi
}
