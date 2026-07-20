#!/usr/bin/env bash

if [[ -n "${AERO7_BINARY_REPO_LOADED:-}" ]]; then
  return 0
fi
AERO7_BINARY_REPO_LOADED=1

aero7_binary_repo_load_config() {
  AERO7_BINARY_REPOSITORY_NAME="${AERO7_BINARY_REPOSITORY_NAME:-aero7}"
  if [[ -z "${AERO7_BINARY_REPOSITORY_SERVER+x}" ]]; then
    AERO7_BINARY_REPOSITORY_SERVER='https://memegeko.github.io/aero7-repo/$arch'
  fi
  AERO7_BINARY_REPOSITORY_KEY_FILE="${AERO7_BINARY_REPOSITORY_KEY_FILE:-$AERO7_PROJECT_ROOT/keys/aero7-repository.asc}"
  AERO7_BINARY_REPOSITORY_FINGERPRINT="${AERO7_BINARY_REPOSITORY_FINGERPRINT:-MANUAL_ACTION_REQUIRED}"
  if [[ -r "$AERO7_CONFIG_DIR/binary-repository.conf" ]]; then
    # shellcheck source=config/binary-repository.conf
    source "$AERO7_CONFIG_DIR/binary-repository.conf"
  fi
  AERO7_PACMAN_CONF="${AERO7_PACMAN_CONF:-/etc/pacman.conf}"
  AERO7_PACMAN_AERO7_CONF="${AERO7_PACMAN_AERO7_CONF:-/etc/pacman.d/aero7.conf}"
  AERO7_PACMAN_AERO7_MIRRORLIST="${AERO7_PACMAN_AERO7_MIRRORLIST:-/etc/pacman.d/aero7-mirrorlist}"
  export AERO7_BINARY_REPOSITORY_NAME AERO7_BINARY_REPOSITORY_SERVER
  export AERO7_BINARY_REPOSITORY_KEY_FILE AERO7_BINARY_REPOSITORY_FINGERPRINT
  export AERO7_PACMAN_CONF AERO7_PACMAN_AERO7_CONF AERO7_PACMAN_AERO7_MIRRORLIST
}

aero7_binary_repo_packages() {
  aero7_load_package_file "$AERO7_CONFIG_DIR/aur-packages.conf"
}

aero7_binary_repo_fingerprint_ready() {
  aero7_binary_repo_load_config
  aero7_repository_key_configured
}

aero7_binary_packages_preferred() {
  case "${AERO7_PACKAGE_MODE:-auto}" in
    source) return 1 ;;
    binary) return 0 ;;
    auto) aero7_binary_repo_fingerprint_ready ;;
    *) aero7_die "Unknown package mode: ${AERO7_PACKAGE_MODE:-auto}" ;;
  esac
}

aero7_source_build_may_be_needed() {
  case "${AERO7_PACKAGE_MODE:-auto}" in
    source) return 0 ;;
    binary) [[ "${AERO7_ALLOW_SOURCE_FALLBACK:-0}" == "1" ]] ;;
    auto)
      if aero7_binary_packages_preferred; then
        [[ "${AERO7_ALLOW_SOURCE_FALLBACK:-0}" == "1" ]]
      else
        return 0
      fi
      ;;
    *) aero7_die "Unknown package mode: ${AERO7_PACKAGE_MODE:-auto}" ;;
  esac
}

aero7_binary_repo_conf_text() {
  cat <<EOF
[$AERO7_BINARY_REPOSITORY_NAME]
SigLevel = Required DatabaseRequired
Include = $AERO7_PACMAN_AERO7_MIRRORLIST
EOF
}

aero7_binary_repo_mirrorlist_text() {
  printf 'Server = %s\n' "$AERO7_BINARY_REPOSITORY_SERVER"
}

aero7_binary_repo_configured_in_pacman() {
  [[ -r "$AERO7_PACMAN_CONF" ]] &&
    grep -Eq "^[[:space:]]*Include[[:space:]]*=[[:space:]]*$AERO7_PACMAN_AERO7_CONF([[:space:]]|$)" "$AERO7_PACMAN_CONF"
}

aero7_binary_repo_write_user_or_root() {
  local path="$1"
  local mode="$2"
  local content="$3"
  if aero7_dry_run; then
    aero7_detail "Would write $path"
    return 0
  fi
  if [[ "$path" == "$AERO7_USER_STATE_DIR"* || -n "${AERO7_TEST_ROOT:-}" ]]; then
    mkdir -p -- "$(dirname -- "$path")"
    printf '%s\n' "$content" >"$path"
    chmod "$mode" "$path"
  else
    printf '%s\n' "$content" | aero7_write_root_text "$path" "$mode"
  fi
}

aero7_binary_repo_enable() {
  aero7_binary_repo_load_config
  aero7_repository_key_import_to_pacman || return 1
  aero7_binary_repo_write_user_or_root "$AERO7_PACMAN_AERO7_MIRRORLIST" 0644 "$(aero7_binary_repo_mirrorlist_text)"
  aero7_binary_repo_write_user_or_root "$AERO7_PACMAN_AERO7_CONF" 0644 "$(aero7_binary_repo_conf_text)"
  if aero7_dry_run; then
    aero7_detail "Would include $AERO7_PACMAN_AERO7_CONF from $AERO7_PACMAN_CONF"
    return 0
  fi
  if ! aero7_binary_repo_configured_in_pacman; then
    if [[ "$AERO7_PACMAN_CONF" == "$AERO7_USER_STATE_DIR"* || -n "${AERO7_TEST_ROOT:-}" ]]; then
      printf '\nInclude = %s\n' "$AERO7_PACMAN_AERO7_CONF" >>"$AERO7_PACMAN_CONF"
    else
      printf '\nInclude = %s\n' "$AERO7_PACMAN_AERO7_CONF" | aero7_sudo tee -a "$AERO7_PACMAN_CONF" >/dev/null
    fi
  fi
}

aero7_binary_repo_disable() {
  aero7_binary_repo_load_config
  if aero7_dry_run; then
    aero7_detail "Would disable Aero7 pacman repository include."
    return 0
  fi
  [[ -r "$AERO7_PACMAN_CONF" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  grep -Ev "^[[:space:]]*Include[[:space:]]*=[[:space:]]*$AERO7_PACMAN_AERO7_CONF([[:space:]]|$)" "$AERO7_PACMAN_CONF" >"$tmp" || true
  if [[ "$AERO7_PACMAN_CONF" == "$AERO7_USER_STATE_DIR"* || -n "${AERO7_TEST_ROOT:-}" ]]; then
    cat "$tmp" >"$AERO7_PACMAN_CONF"
  else
    aero7_sudo install -m 0644 "$tmp" "$AERO7_PACMAN_CONF"
  fi
  rm -- "$tmp"
}

aero7_binary_repo_refresh() {
  local args=()
  mapfile -t args < <(aero7_pacman_install_args)
  AERO7_COMMAND_STREAM=0 aero7_sudo_run pacman -Syy "${args[@]}"
}

aero7_binary_repo_package_available() {
  local package="$1"
  pacman -Si "$AERO7_BINARY_REPOSITORY_NAME/$package" >/dev/null 2>&1
}

aero7_binary_repo_all_packages_available() {
  local missing=()
  local package
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    if ! aero7_binary_repo_package_available "$package"; then
      missing+=("$package")
    fi
  done < <(aero7_binary_repo_packages)
  if [[ "${#missing[@]}" -gt 0 ]]; then
    aero7_warn "Aero7 binary repository is missing package(s): ${missing[*]}"
    return 1
  fi
  return 0
}

aero7_binary_repo_prepare() {
  aero7_binary_repo_load_config
  if ! aero7_binary_packages_preferred; then
    aero7_skip "Signed Aero7 repository is not configured yet; source build path remains active."
    aero7_state_set "binary_repo_ready" "no"
    return 0
  fi
  aero7_action "Configuring signed Aero7 package repository"
  if ! aero7_repository_key_verify_file; then
    aero7_state_set "binary_repo_ready" "no"
    if aero7_non_interactive && [[ "${AERO7_ALLOW_SOURCE_FALLBACK:-0}" != "1" ]]; then
      aero7_die "Signed Aero7 repository key is not ready. Use --source-build or --allow-source-fallback to build from source."
    fi
    aero7_warn "Signed Aero7 repository is unavailable; source build fallback may be required."
    return 0
  fi
  aero7_binary_repo_enable
  if ! aero7_dry_run; then
    aero7_binary_repo_refresh
    aero7_binary_repo_all_packages_available || {
      aero7_state_set "binary_repo_ready" "no"
      if aero7_non_interactive && [[ "${AERO7_ALLOW_SOURCE_FALLBACK:-0}" != "1" ]]; then
        return 1
      fi
      aero7_warn "Signed Aero7 repository package validation failed; source build fallback may be required."
      return 0
    }
  fi
  aero7_state_set "binary_repo_ready" "yes"
}

aero7_binary_repo_install_packages() {
  local packages=()
  local package args=()
  mapfile -t packages < <(aero7_binary_repo_packages)
  [[ "${#packages[@]}" -gt 0 ]] || aero7_die "No Aero7 packages configured for binary installation."
  aero7_validate_no_x11_packages_configured "${packages[@]}" || return 1
  aero7_action "Downloading signed Aero7 packages"
  if aero7_dry_run; then
    local dry_index=0
    for package in "${packages[@]}"; do
      dry_index=$((dry_index + 1))
      aero7_progress_item "$dry_index" "${#packages[@]}" "$package"
      aero7_state_append "package_origin" "$package=Aero7 signed repository"
    done
    aero7_state_set "aero_packages_origin" "binary"
    return 0
  fi
  mapfile -t args < <(aero7_pacman_install_args)
  local repo_packages=()
  for package in "${packages[@]}"; do
    repo_packages+=("$AERO7_BINARY_REPOSITORY_NAME/$package")
  done
  if declare -F aero7_tui_backend >/dev/null 2>&1 && aero7_tui_backend; then
    local tui_index=0
    for package in "${packages[@]}"; do
      tui_index=$((tui_index + 1))
      aero7_event_emit action_start \
        "title=Downloading signed Aero7 packages" \
        "stage=${AERO7_CURRENT_STAGE:-startup}" \
        "package_current=$tui_index" \
        "package_total=${#packages[@]}" \
        "package=$package"
      aero7_progress_item "$tui_index" "${#packages[@]}" "$package"
    done
  else
    local index=0
    for package in "${packages[@]}"; do
      index=$((index + 1))
      aero7_progress_item "$index" "${#packages[@]}" "$package"
    done
  fi
  aero7_sudo_run pacman -S --needed "${args[@]}" "${repo_packages[@]}"
  for package in "${packages[@]}"; do
    aero7_state_append "installed_binary_packages" "$package"
    aero7_state_append "package_origin" "$package=Aero7 signed repository"
  done
  aero7_state_set "aero_packages_origin" "binary"
  aero7_ok "${#packages[@]} signed Aero7 package(s) installed"
}

aero7_source_fallback_allowed_or_prompt() {
  [[ "${AERO7_ALLOW_SOURCE_FALLBACK:-0}" == "1" ]] && return 0
  if aero7_non_interactive; then
    return 1
  fi
  if declare -F aero7_prompt_box >/dev/null 2>&1; then
    aero7_prompt_box \
      "Aero7 packages" \
      "Precompiled Aero7 packages are unavailable or incompatible." \
      "Building from source may take 30-90 minutes." >&2
  else
    printf '\nPrecompiled Aero7 packages are unavailable or incompatible.\n' >&2
    printf 'Building from source may take 30-90 minutes.\n' >&2
  fi
  aero7_confirm "Build from source instead?" "no"
}

aero7_install_aero_packages() {
  case "${AERO7_PACKAGE_MODE:-auto}" in
    source)
      aero7_state_set "aero_packages_origin" "source"
      aero7_install_yay
      aero7_install_configured_aur_packages
      return 0
      ;;
  esac

  if [[ "$(aero7_state_get binary_repo_ready 2>/dev/null || printf no)" == "yes" ]]; then
    if aero7_binary_repo_install_packages; then
      return 0
    fi
  fi

  if [[ "${AERO7_PACKAGE_MODE:-auto}" == "binary" ]] ||
    { [[ "${AERO7_PACKAGE_MODE:-auto}" == "auto" ]] && aero7_binary_packages_preferred; }; then
    aero7_warn "Precompiled Aero7 packages are unavailable or incompatible."
    aero7_source_fallback_allowed_or_prompt || aero7_die "Cancelled because signed Aero7 binary packages are unavailable."
  fi

  aero7_state_set "aero_packages_origin" "source"
  aero7_install_yay
  aero7_install_configured_aur_packages
}

aero7_repo_cmd() {
  local sub="${1:-status}"
  aero7_binary_repo_load_config
  case "$sub" in
    status)
      printf 'Aero7-shell Repository\n'
      aero7_cmd_kv "Name" "$AERO7_BINARY_REPOSITORY_NAME"
      aero7_cmd_kv "Server" "$AERO7_BINARY_REPOSITORY_SERVER"
      aero7_cmd_kv "Configured" "$(aero7_binary_repo_configured_in_pacman && printf yes || printf no)"
      aero7_cmd_kv "Fingerprint" "$AERO7_BINARY_REPOSITORY_FINGERPRINT"
      aero7_cmd_kv "Ready" "$(aero7_state_get binary_repo_ready 2>/dev/null || printf unknown)"
      ;;
    enable) aero7_binary_repo_enable ;;
    disable) aero7_binary_repo_disable ;;
    key) aero7_repository_key_verify_file && printf '%s\n' "$AERO7_BINARY_REPOSITORY_KEY_FILE" ;;
    fingerprint) printf '%s\n' "$AERO7_BINARY_REPOSITORY_FINGERPRINT" ;;
    packages) aero7_binary_repo_packages ;;
    refresh) aero7_binary_repo_refresh ;;
    doctor)
      aero7_repository_key_verify_file || return 1
      aero7_binary_repo_configured_in_pacman || return 1
      aero7_binary_repo_all_packages_available
      ;;
    *) aero7_die "Usage: aero7 repo [status|enable|disable|key|fingerprint|packages|refresh|doctor]" ;;
  esac
}
