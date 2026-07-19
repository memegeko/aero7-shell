#!/usr/bin/env bash

if [[ -n "${AERO7_AUR_LOADED:-}" ]]; then
  return 0
fi
AERO7_AUR_LOADED=1

AERO7_AUR_PROHIBITED=(
  aerothemeplasma-desktop-x11-git
  aeroshell-kwin-components-x11-git
  aeroshell-smodglow-x11-git
  kwin-x11
  plasma-x11-session
)

aero7_aur_guard_not_root() {
  if aero7_is_root; then
    aero7_die "AUR builds and yay must never run as root."
  fi
}

aero7_aur_guard_package() {
  local package="$1"
  local prohibited
  for prohibited in "${AERO7_AUR_PROHIBITED[@]}"; do
    if [[ "$package" == "$prohibited" ]]; then
      aero7_die "Refusing prohibited or unsafe AUR package: $package"
    fi
  done
}

aero7_aur_package_exists() {
  local package="$1"
  if ! aero7_have curl; then
    return 0
  fi
  curl -fsSL "https://aur.archlinux.org/rpc/v5/info/$package" | grep -q '"resultcount":1'
}

aero7_aur_needs_conflict_resolution() {
  local package
  for package in "$@"; do
    case "$package" in
      aeroshell-libplasma-git)
        return 0
        ;;
    esac
  done
  return 1
}

aero7_yay_available() {
  aero7_have yay && yay --version >/dev/null 2>&1
}

aero7_yay_install_package_group() {
  local needs_conflict_resolution="$1"
  shift
  local packages=("$@")
  local args=(-S --needed)
  local auto_answer=0
  local stream=0

  [[ "${#packages[@]}" -gt 0 ]] || return 0

  if aero7_non_interactive || [[ "${AERO7_ASSUME_YES:-0}" == "1" ]]; then
    args+=(
      --answerclean None
      --answerdiff None
      --answeredit None
      --answerupgrade None
      --cleanmenu=false
      --diffmenu=false
      --editmenu=false
      --provides=false
      --sudoloop
      --batchinstall
      --removemake
      --mflags=--noconfirm
    )
    auto_answer=1
    if [[ "$needs_conflict_resolution" -eq 0 ]]; then
      args+=(--noconfirm)
    fi
  fi

  if [[ "$needs_conflict_resolution" -eq 1 ]]; then
    args+=(--useask)
  fi

  if [[ "$needs_conflict_resolution" -eq 1 && "$auto_answer" -eq 1 ]]; then
    aero7_run_with_repeated_input "" y yay "${args[@]}" "${packages[@]}"
  else
    if [[ "$auto_answer" -eq 0 ]]; then
      stream=1
    fi
    AERO7_COMMAND_STREAM="$stream" aero7_run yay "${args[@]}" "${packages[@]}"
  fi
}

aero7_install_yay() {
  aero7_require_arch_or_dry_run
  aero7_aur_guard_not_root
  if aero7_yay_available; then
    aero7_skip "yay is already available"
    return 0
  fi

  aero7_action "Preparing yay AUR helper"
  aero7_pacman_install_needed git base-devel go

  local source_dir="$AERO7_CACHE_DIR/sources/yay"
  local makepkg_args=()
  local pacman_args=()
  local stream=0
  if aero7_non_interactive || [[ "${AERO7_ASSUME_YES:-0}" == "1" ]]; then
    makepkg_args+=(--noconfirm)
  else
    stream=1
  fi
  if aero7_dry_run; then
    aero7_detail "Would clone and build yay in $source_dir"
    return 0
  fi

  aero7_detail "Preparing source directory"
  aero7_user_run install -d -m 0755 "$AERO7_CACHE_DIR/sources"
  if [[ -d "$source_dir/.git" ]]; then
    aero7_detail "Updating yay source"
    aero7_user_run git -C "$source_dir" pull --ff-only
  else
    aero7_detail "Cloning yay source"
    aero7_user_run git clone https://aur.archlinux.org/yay.git "$source_dir"
  fi
  aero7_detail "Building yay"
  # shellcheck disable=SC2016
  AERO7_COMMAND_STREAM="$stream" aero7_user_run bash -lc 'cd "$1" && shift && makepkg "$@"' _ "$source_dir" "${makepkg_args[@]}"
  local package_file
  package_file="$(find "$source_dir" -maxdepth 1 -type f -name 'yay-[0-9]*-*.pkg.tar.*' ! -name '*.sig' | sort -V | tail -n 1)"
  [[ -n "$package_file" ]] || aero7_die "yay package build did not produce an installable package."
  mapfile -t pacman_args < <(aero7_pacman_install_args)
  aero7_detail "Installing yay"
  AERO7_COMMAND_STREAM="$stream" aero7_sudo_run pacman -U "${pacman_args[@]}" "$package_file"
  yay --version >/dev/null 2>&1 || aero7_die "yay installation did not validate."
  aero7_ok "yay installed"
}

aero7_yay_install_packages() {
  aero7_aur_guard_not_root
  local packages=("$@")
  local package
  local conflict_packages=()
  local normal_packages=()

  for package in "${packages[@]}"; do
    aero7_aur_guard_package "$package"
  done

  if aero7_dry_run; then
    aero7_action "Installing Aero packages from the AUR"
    local dry_index=0
    for package in "${packages[@]}"; do
      dry_index=$((dry_index + 1))
      aero7_progress_item "$dry_index" "${#packages[@]}" "$package"
    done
    return 0
  fi

  aero7_yay_available || aero7_die "yay is not installed."
  for package in "${packages[@]}"; do
    if ! aero7_aur_package_exists "$package"; then
      aero7_die "AUR package not found: $package"
    fi
  done

  for package in "${packages[@]}"; do
    if aero7_aur_needs_conflict_resolution "$package"; then
      conflict_packages+=("$package")
    else
      normal_packages+=("$package")
    fi
  done

  aero7_action "Installing Aero packages from the AUR"
  if declare -F aero7_tui_backend >/dev/null 2>&1 && aero7_tui_backend; then
    local tui_index=0
    for package in "${packages[@]}"; do
      tui_index=$((tui_index + 1))
      aero7_progress_item "$((tui_index - 1))" "${#packages[@]}" "$package"
      aero7_event_emit action_start \
        "title=Building $package" \
        "stage=${AERO7_CURRENT_STAGE:-startup}" \
        "package_current=$tui_index" \
        "package_total=${#packages[@]}" \
        "package=$package"
      if aero7_aur_needs_conflict_resolution "$package"; then
        aero7_yay_install_package_group 1 "$package"
      else
        aero7_yay_install_package_group 0 "$package"
      fi
      aero7_state_append "installed_aur_packages" "$package"
      aero7_progress_item "$tui_index" "${#packages[@]}" "$package"
      aero7_ok "$package installed"
    done
    aero7_ok "${#packages[@]} AUR package(s) installed"
    return 0
  fi

  local index=0
  for package in "${packages[@]}"; do
    index=$((index + 1))
    aero7_progress_item "$index" "${#packages[@]}" "$package"
  done
  aero7_detail "AUR builds can take several minutes; full build output is saved to the log."
  aero7_yay_install_package_group 1 "${conflict_packages[@]}"
  aero7_yay_install_package_group 0 "${normal_packages[@]}"
  for package in "${packages[@]}"; do
    aero7_state_append "installed_aur_packages" "$package"
  done
  aero7_ok "${#packages[@]} AUR package(s) installed"
}

aero7_install_configured_aur_packages() {
  local file="${1:-$AERO7_CONFIG_DIR/aur-packages.conf}"
  local packages=()
  mapfile -t packages < <(aero7_load_package_file "$file")
  [[ "${#packages[@]}" -gt 0 ]] || aero7_die "No AUR packages found in $file."
  aero7_yay_install_packages "${packages[@]}"
}
