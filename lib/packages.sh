#!/usr/bin/env bash

if [[ -n "${AERO7_PACKAGES_LOADED:-}" ]]; then
  return 0
fi
AERO7_PACKAGES_LOADED=1

aero7_pacman_available() {
  local package="$1"
  pacman -Si "$package" >/dev/null 2>&1
}

aero7_pacman_installed() {
  local package="$1"
  pacman -Qq "$package" >/dev/null 2>&1
}

aero7_pacman_install_args() {
  if aero7_non_interactive || [[ "${AERO7_ASSUME_YES:-0}" == "1" ]]; then
    printf '%s\n' "--noconfirm"
  fi
}

aero7_pacman_system_update() {
  aero7_require_arch_or_dry_run
  if ! aero7_have pacman && ! aero7_dry_run; then
    aero7_die "pacman is required on Arch Linux."
  fi

  local args=()
  local stream=0
  mapfile -t args < <(aero7_pacman_install_args)
  if ! aero7_non_interactive && [[ "${AERO7_ASSUME_YES:-0}" != "1" ]]; then
    stream=1
  fi
  aero7_action "Updating system packages"
  AERO7_COMMAND_STREAM="$stream" aero7_sudo_run pacman -Syu "${args[@]}"
  aero7_ok "System packages updated"
}

aero7_pacman_install_needed() {
  aero7_require_arch_or_dry_run
  local packages=("$@")
  local unavailable=()
  local already=()
  local missing=()
  local package
  local args=()
  local stream=0

  if aero7_dry_run; then
    aero7_action "Installing ${#packages[@]} required package(s)"
    aero7_detail "Would install: ${packages[*]}"
    return 0
  fi

  for package in "${packages[@]}"; do
    if ! aero7_pacman_available "$package"; then
      unavailable+=("$package")
    elif aero7_pacman_installed "$package"; then
      already+=("$package")
    else
      missing+=("$package")
    fi
  done

  if [[ "${#unavailable[@]}" -gt 0 ]]; then
    aero7_fail "Unavailable pacman package(s)"
    if declare -F aero7_tui_backend >/dev/null 2>&1 &&
      aero7_tui_backend &&
      declare -F aero7_event_action_output >/dev/null 2>&1; then
      for package in "${unavailable[@]}"; do
        aero7_event_action_output "Unavailable: $package"
      done
    else
      printf '      %s\n' "${unavailable[@]}" >&2
    fi
    return 1
  fi

  aero7_action "Installing ${#packages[@]} required package(s)"
  if [[ "${#missing[@]}" -eq 0 ]]; then
    aero7_skip "${#already[@]} package(s) already present"
    for package in "${packages[@]}"; do
      aero7_state_append "installed_core_packages" "$package"
    done
    return 0
  fi

  mapfile -t args < <(aero7_pacman_install_args)
  if ! aero7_non_interactive && [[ "${AERO7_ASSUME_YES:-0}" != "1" ]]; then
    stream=1
  fi
  AERO7_COMMAND_STREAM="$stream" aero7_sudo_run pacman -S --needed "${args[@]}" "${packages[@]}"
  aero7_ok "${#missing[@]} package(s) installed"
  if [[ "${#already[@]}" -gt 0 ]]; then
    aero7_skip "${#already[@]} package(s) already present"
  fi
  for package in "${packages[@]}"; do
    aero7_state_append "installed_core_packages" "$package"
  done
}

aero7_install_configured_pacman_packages() {
  local file="${1:-$AERO7_CONFIG_DIR/packages.conf}"
  local packages=()
  mapfile -t packages < <(aero7_load_package_file "$file")
  [[ "${#packages[@]}" -gt 0 ]] || aero7_die "No packages found in $file."
  aero7_pacman_install_needed "${packages[@]}"
}

aero7_configured_pacman_packages_installed() {
  local file="${1:-$AERO7_CONFIG_DIR/packages.conf}"
  local packages=()
  local missing=()
  local package
  mapfile -t packages < <(aero7_load_package_file "$file")
  [[ "${#packages[@]}" -gt 0 ]] || aero7_die "No packages found in $file."

  for package in "${packages[@]}"; do
    if ! aero7_pacman_installed "$package"; then
      missing+=("$package")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    aero7_warn "Required pacman package(s) missing despite saved state: ${missing[*]}"
    return 1
  fi
  return 0
}

aero7_validate_no_x11_packages_installed() {
  local prohibited=(
    aerothemeplasma-desktop-x11-git
    aeroshell-kwin-components-x11-git
    aeroshell-smodglow-x11-git
    kwin-x11
    plasma-x11-session
  )
  local package
  for package in "${prohibited[@]}"; do
    if aero7_have pacman && aero7_pacman_installed "$package"; then
      aero7_warn "Prohibited X11 package is installed: $package"
      return 1
    fi
  done
  return 0
}

aero7_x11_denylist() {
  cat <<'EOF'
aerothemeplasma-desktop-x11-git
aeroshell-kwin-components-x11-git
aeroshell-smodglow-x11-git
kwin-x11
plasma-x11-session
EOF
}

aero7_validate_no_x11_packages_configured() {
  local package denied file
  local files=("$AERO7_CONFIG_DIR/packages.conf" "$AERO7_CONFIG_DIR/aur-packages.conf")
  for file in "${files[@]}"; do
    [[ -r "$file" ]] || continue
    while IFS= read -r denied; do
      [[ -n "$denied" ]] || continue
      if awk 'NF && $1 !~ /^#/ { print $1 }' "$file" | grep -Fxq "$denied"; then
        aero7_warn "Prohibited X11 package appears in install list $file: $denied"
        return 1
      fi
    done < <(aero7_x11_denylist)
  done

  for package in "$@"; do
    while IFS= read -r denied; do
      if [[ "$package" == "$denied" ]]; then
        aero7_warn "Prohibited X11 package requested for install: $package"
        return 1
      fi
    done < <(aero7_x11_denylist)
  done
  return 0
}
