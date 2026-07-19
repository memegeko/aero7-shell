#!/usr/bin/env bash

if [[ -n "${AERO7_OWNERSHIP_LOADED:-}" ]]; then
  return 0
fi
AERO7_OWNERSHIP_LOADED=1

aero7_managed_user_roots() {
  aero7_detect_user
  printf '%s\n' "$AERO7_HOME/.config/aero7-shell"
  printf '%s\n' "$AERO7_USER_STATE_DIR"
  printf '%s\n' "$AERO7_CACHE_DIR"
  printf '%s\n' "$AERO7_HOME/.config/fastfetch"
}

aero7_path_is_managed_user_path() {
  local path="$1"
  local root canonical_path canonical_root
  canonical_path="$(aero7_canonical_path "$path")"
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    canonical_root="$(aero7_canonical_path "$root")"
    if aero7_path_under "$canonical_path" "$canonical_root"; then
      return 0
    fi
  done < <(aero7_managed_user_roots)
  return 1
}

aero7_root_owned_managed_user_files() {
  local root
  while IFS= read -r root; do
    [[ -d "$root" ]] || continue
    find "$root" -xdev \( -type f -o -type d -o -type l \) -uid 0 -print
  done < <(aero7_managed_user_roots)
}

aero7_repair_root_owned_managed_user_files() {
  local path found=0
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    aero7_path_is_managed_user_path "$path" || aero7_die "Refusing to repair unmanaged path: $path"
    found=1
    aero7_sudo_run chown -h "$AERO7_USER:$AERO7_USER" "$path"
  done < <(aero7_root_owned_managed_user_files)

  if [[ "$found" -eq 0 ]]; then
    aero7_info "No root-owned Aero7-managed user files found."
  fi
}

