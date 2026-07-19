#!/usr/bin/env bash
# Several assertions intentionally run in subshells to test fatal guard helpers
# without terminating this test process.
# shellcheck disable=SC2030,SC2031,SC2317
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export AERO7_PROJECT_ROOT="$repo"
export AERO7_DRY_RUN=1

source "$repo/lib/common.sh"
source "$repo/lib/state.sh"
source "$repo/lib/packages.sh"
source "$repo/lib/aur.sh"
source "$repo/lib/applications.sh"
source "$repo/lib/bootloader.sh"
source "$repo/lib/initramfs.sh"
source "$repo/lib/plasma.sh"
source "$repo/lib/ownership.sh"
source "$repo/lib/validation.sh"

fail() {
  printf 'test-policy: %s\n' "$*" >&2
  exit 1
}

aero7_init_paths

unset AERO7_SUDO_KEEPALIVE_PID
aero7_sudo_keepalive_start
[[ -z "${AERO7_SUDO_KEEPALIVE_PID:-}" ]] || fail "sudo keepalive started during dry-run"
aero7_sudo_keepalive_stop
grep -q 'AERO7_SUDO_KEEPALIVE_INTERVAL:-15' "$repo/lib/common.sh" || fail "sudo keepalive interval is not short enough for long AUR builds"
grep -q 'sudo credential keepalive stopped' "$repo/lib/common.sh" || fail "sudo keepalive stop is not logged"

while IFS= read -r denied; do
  [[ -n "$denied" ]] || continue
  if awk 'NF && $1 !~ /^#/ { print $1 }' "$repo/config/packages.conf" "$repo/config/aur-packages.conf" | grep -Fxq "$denied"; then
    fail "denylisted X11 package appears in install lists: $denied"
  fi
done < <(aero7_x11_denylist)

for allowed in aerothemeplasma-desktop-git aeroshell-libplasma-git aeroshell-workspace-git aeroshell-kwin-components-git; do
  if ! awk 'NF && $1 !~ /^#/ { print $1 }' "$repo/config/aur-packages.conf" | grep -Fxq "$allowed"; then
    fail "full Wayland AeroThemePlasma package is missing from AUR install list: $allowed"
  fi
  if ! (aero7_aur_guard_package "$allowed") >/dev/null 2>&1; then
    fail "AUR guard rejected full Wayland AeroThemePlasma package: $allowed"
  fi
done

while IFS= read -r denied; do
  [[ -n "$denied" ]] || continue
  if awk 'NF && $1 !~ /^#/ { print $1 }' "$repo/config/aur-packages.conf" | grep -Fxq "$denied"; then
    fail "denylisted X11 package appears in AUR install list: $denied"
  fi
  if (aero7_aur_guard_package "$denied") >/dev/null 2>&1; then
    fail "AUR guard allowed X11 package: $denied"
  fi
done < <(aero7_x11_denylist)

if rg -n 'PlymouthVista|Windows Boot Manager|Starting Windows' "$repo/stages" "$repo/config" >/dev/null; then
  fail "Plymouth stage/config references Microsoft-branded or proprietary-style boot theme assets"
fi

for disabled in aero-dolphin aero-gwenview control-panel; do
  recipe="$repo/recipes/$disabled.sh"
  aero7_recipe_load "$recipe"
  [[ "$AERO7_APP_AVAILABLE" == "no" ]] || fail "$disabled should remain disabled until VM replacement/build validation is explicit"
done

for dangerous in "" "/" "/home" "$AERO7_HOME" "/usr" "/etc" "/boot"; do
  if (AERO7_DRY_RUN=1; aero7_safe_remove_tree "$dangerous" "$repo") >/dev/null 2>&1; then
    fail "safe remove allowed dangerous path: ${dangerous:-<empty>}"
  fi
done

merged="$(aero7_merge_kernel_params 'quiet splash loglevel=3' quiet splash)"
[[ "$merged" == "quiet splash loglevel=3" ]] || fail "kernel parameter duplicate prevention failed: $merged"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
entry="$tmp/arch.conf"
updated="$tmp/arch-updated.conf"
cat >"$entry" <<'EOF'
title Arch Linux
linux /vmlinuz-linux
initrd /amd-ucode.img
initrd /initramfs-linux.img
options root=UUID=test rw quiet
EOF
aero7_update_systemd_boot_entry_file "$entry" "$updated" quiet splash
grep -q '^initrd /amd-ucode.img$' "$updated" || fail "systemd-boot entry did not preserve first initrd"
grep -q '^initrd /initramfs-linux.img$' "$updated" || fail "systemd-boot entry did not preserve second initrd"
[[ "$(grep -o 'quiet' "$updated" | wc -l)" -eq 1 ]] || fail "systemd-boot duplicated quiet"

root="$tmp/root"
mkdir -p "$root/usr/share/wayland-sessions"
AERO7_TEST_ROOT="$root"
if aero7_validate_plasma_wayland_session; then
  fail "missing Wayland session validated successfully"
fi
cat >"$root/usr/share/wayland-sessions/plasma.desktop" <<'EOF'
[Desktop Entry]
Name=Plasma (Wayland)
Exec=startplasma-wayland
EOF
aero7_validate_plasma_wayland_session || fail "valid Plasma Wayland session was not detected"
cat >"$root/usr/share/wayland-sessions/aerothemeplasma.desktop" <<'EOF'
[Desktop Entry]
Name=AeroThemePlasma (Wayland)
Exec=startatp-wayland
EOF
[[ "$(aero7_find_atp_wayland_session)" == "aerothemeplasma.desktop" ]] || fail "AeroThemePlasma Wayland session was not detected"

mkdir -p "$root/usr/share/sddm/themes"
[[ -z "$(aero7_find_sddm_aero_theme || true)" ]] || fail "missing SDDM theme should not resolve"
mkdir -p "$root/usr/share/sddm/themes/aero7-test"
[[ "$(aero7_find_sddm_aero_theme)" == "aero7-test" ]] || fail "Aero SDDM theme was not detected"
mkdir -p "$root/usr/share/sddm/themes/sddm-theme-mod"
[[ "$(aero7_find_sddm_aero_theme)" == "sddm-theme-mod" ]] || fail "upstream AeroThemePlasma SDDM theme was not preferred"

(
  unset DISPLAY WAYLAND_DISPLAY
  ! aero7_graphical_session_available || fail "headless shell was detected as graphical"
  WAYLAND_DISPLAY=wayland-1
  aero7_graphical_session_available || fail "Wayland display was not detected as graphical"
)

state="$tmp/state"
export AERO7_STATE_ROOT_OVERRIDE="$state"
aero7_state_init
aero7_state_append installed_core_packages plasma-desktop
aero7_state_append skipped_applications "linver: disabled"
aero7_state_append failed_optional_applications "example: failed"
report="$(aero7_final_report)"
[[ "$report" == *"Successfully installed core packages:"* ]] || fail "final report missing core package section"
[[ "$report" == *"Skipped applications:"* ]] || fail "final report missing skipped section"
[[ "$report" == *"Failed optional applications:"* ]] || fail "final report missing failed section"

managed="$tmp/managed/.config/aero7-shell"
mkdir -p "$managed"
touch "$managed/root-owned"
ownership_checked=0
if [[ "$(id -u)" -eq 0 ]]; then
  ownership_checked=1
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo chown root:root "$managed/root-owned"
  ownership_checked=1
else
  printf 'test-policy: skipping root-owned file ownership fixture; sudo root chown unavailable\n'
fi
if [[ "$ownership_checked" -eq 1 ]]; then
  export AERO7_HOME="$tmp/managed"
  export AERO7_USER_STATE_DIR="$tmp/managed/.local/state/aero7-shell"
  export AERO7_CACHE_DIR="$tmp/managed/.cache/aero7-shell"
  if ! aero7_root_owned_managed_user_files | grep -q 'root-owned'; then
    fail "root-owned managed user file was not detected"
  fi
fi

run_output="$tmp/noninteractive.out"
env -u AERO7_STATE_ROOT_OVERRIDE \
  -u AERO7_TEST_ROOT \
  -u AERO7_MKINITCPIO_CONF \
  -u AERO7_DRACUT_DROPIN \
  -u AERO7_HOME \
  AERO7_USER_STATE_DIR="$tmp/noninteractive-state" \
  "$repo/install.sh" --dry-run --non-interactive --no-reboot >"$run_output"
! grep -q 'Reboot now?' "$run_output" || fail "noninteractive dry-run offered reboot"
grep -q '^kept$' "$tmp/noninteractive-state/dry-run/state/options/layout" || fail "noninteractive dry-run did not keep layout by default"

(
  export AERO7_DRY_RUN=0
  export AERO7_SYSTEM_STATE_DIR="$tmp/system-state"
  export AERO7_STATE_ROOT_OVERRIDE="$tmp/state-mk"
  unset AERO7_TEST_ROOT
  mkroot="$tmp/mkroot"
  mkdir -p "$mkroot/etc"
  cat >"$mkroot/etc/mkinitcpio.conf" <<'EOF'
HOOKS=(base udev autodetect modconf block filesystems fsck)
EOF
  original_text="$(cat "$mkroot/etc/mkinitcpio.conf")"
  export AERO7_TEST_ROOT="$mkroot"
  export AERO7_MKINITCPIO_CONF="$mkroot/etc/mkinitcpio.conf"
  aero7_sudo() { "$@"; }
  aero7_sudo_run() { "$@"; }
  aero7_run_mkinitcpio_rebuild() { return 1; }
  if aero7_configure_initramfs_for_plymouth >/dev/null 2>&1; then
    fail "mkinitcpio failure was reported as success"
  fi
  [[ "$(cat "$mkroot/etc/mkinitcpio.conf")" == "$original_text" ]] || fail "mkinitcpio rollback did not restore original file"
)

(
  export AERO7_DRY_RUN=0
  export AERO7_SYSTEM_STATE_DIR="$tmp/system-state-dr"
  export AERO7_STATE_ROOT_OVERRIDE="$tmp/state-dr"
  drroot="$tmp/drroot"
  mkdir -p "$drroot/etc/dracut.conf.d"
  touch "$drroot/etc/dracut.conf"
  cat >"$drroot/etc/dracut.conf.d/aero7-plymouth.conf" <<'EOF'
# existing local config
EOF
  original_text="$(cat "$drroot/etc/dracut.conf.d/aero7-plymouth.conf")"
  export AERO7_TEST_ROOT="$drroot"
  export AERO7_DRACUT_DROPIN="$drroot/etc/dracut.conf.d/aero7-plymouth.conf"
  aero7_sudo() { "$@"; }
  aero7_sudo_run() { "$@"; }
  aero7_run_dracut_rebuild() { return 1; }
  if aero7_configure_initramfs_for_plymouth >/dev/null 2>&1; then
    fail "dracut failure was reported as success"
  fi
  [[ "$(cat "$drroot/etc/dracut.conf.d/aero7-plymouth.conf")" == "$original_text" ]] || fail "dracut rollback did not restore original drop-in"
)

(
  export AERO7_DRY_RUN=0
  missing_pkg_file="$tmp/missing-packages.conf"
  printf 'present\nmissing\n' >"$missing_pkg_file"
  aero7_pacman_installed() { [[ "$1" == "present" ]]; }
  if aero7_configured_pacman_packages_installed "$missing_pkg_file" >/dev/null 2>&1; then
    fail "configured package validation allowed missing packages from stale state"
  fi
)

(
  export AERO7_DRY_RUN=0
  aero7_have() { [[ "$1" == "systemctl" ]]; }
  aero7_systemd_unit_exists() { [[ "$1" == "NetworkManager.service" ]]; }
  aero7_systemctl_is_enabled() { return 0; }
  if aero7_validate_core_services >/dev/null 2>&1; then
    fail "core service validation allowed missing sddm.service from stale state"
  fi
)

(
  export AERO7_DRY_RUN=0
  export AERO7_ASSUME_YES=1
  export AERO7_NON_INTERACTIVE=1
  export AERO7_CACHE_DIR="$tmp/yay-bootstrap-cache"
  user_log="$tmp/yay-bootstrap-user.log"
  sudo_log="$tmp/yay-bootstrap-sudo.log"
  deps_log="$tmp/yay-bootstrap-deps.log"
  aero7_require_arch_or_dry_run() { return 0; }
  aero7_aur_guard_not_root() { return 0; }
  aero7_yay_available() { return 1; }
  aero7_pacman_install_needed() {
    printf '%s\n' "$*" >>"$deps_log"
  }
  aero7_user_run() {
    printf '%s\n' "$*" >>"$user_log"
    case "${1:-}" in
      install)
        mkdir -p "$AERO7_CACHE_DIR/sources"
        ;;
      git)
        mkdir -p "$AERO7_CACHE_DIR/sources/yay/.git"
        ;;
      bash)
        mkdir -p "$AERO7_CACHE_DIR/sources/yay"
        : >"$AERO7_CACHE_DIR/sources/yay/yay-1-1-x86_64.pkg.tar.zst"
        ;;
    esac
  }
  aero7_sudo_run() {
    printf '%s\n' "$*" >>"$sudo_log"
  }
  yay() {
    [[ "${1:-}" == "--version" ]]
  }
  aero7_install_yay
  grep -q 'git base-devel go' "$deps_log" || fail "yay bootstrap did not install go before makepkg"
  grep -q 'makepkg.*--noconfirm' "$user_log" || fail "yay bootstrap did not build package with makepkg --noconfirm"
  ! grep -q 'makepkg.* -s' "$user_log" || fail "yay bootstrap still let makepkg invoke sudo for dependency installation"
  ! grep -q 'makepkg.*-si' "$user_log" || fail "yay bootstrap still used makepkg -si"
  grep -q 'pacman -U --noconfirm' "$sudo_log" || fail "yay bootstrap did not install through central sudo pacman wrapper"
)

(
  export AERO7_DRY_RUN=0
  export AERO7_ASSUME_YES=1
  export AERO7_NON_INTERACTIVE=1
  yay_log="$tmp/yay-calls.log"
  aero7_aur_guard_not_root() { return 0; }
  aero7_aur_package_exists() { return 0; }
  yay() {
    if [[ "${1:-}" == "--version" ]]; then
      return 0
    fi
    printf '%s\n' "$*" >>"$yay_log"
  }
  aero7_yay_install_packages aeroshell-libplasma-git aerothemeplasma-desktop-git uac-polkit-agent-git
  mapfile -t yay_calls <"$yay_log"
  [[ "${#yay_calls[@]}" -eq 2 ]] || fail "promptless yay install did not split conflict and normal package groups"
  conflict_call="${yay_calls[0]}"
  normal_call="${yay_calls[1]}"
  [[ "$conflict_call" == *"aeroshell-libplasma-git"* ]] || fail "conflict yay group did not install aeroshell-libplasma-git"
  [[ "$conflict_call" != *"aerothemeplasma-desktop-git"* ]] || fail "conflict yay group included normal packages"
  [[ "$conflict_call" == *"--useask"* ]] || fail "conflict yay group missing --useask"
  [[ " $conflict_call " != *" --noconfirm "* ]] || fail "conflict yay group used pacman --noconfirm"
  [[ "$normal_call" == *"aerothemeplasma-desktop-git"* && "$normal_call" == *"uac-polkit-agent-git"* ]] || fail "normal yay group missing normal packages"
  [[ "$normal_call" == *"--noconfirm"* ]] || fail "normal yay group missing --noconfirm"
  [[ "$normal_call" == *"--cleanmenu=false"* && "$normal_call" == *"--diffmenu=false"* && "$normal_call" == *"--editmenu=false"* ]] || fail "normal yay group did not disable yay review menus"
  [[ "$normal_call" == *"--sudoloop"* && "$normal_call" == *"--batchinstall"* && "$normal_call" == *"--removemake"* ]] || fail "normal yay group missing prompt-reduction flags"
  [[ "$normal_call" == *"--mflags=--noconfirm"* ]] || fail "normal yay group missing makepkg --noconfirm"
  [[ "$normal_call" != *"--useask"* ]] || fail "normal yay group used conflict-only --useask"
)

(
  export AERO7_DRY_RUN=0
  AERO7_APP_ID="broken-aur"
  AERO7_APP_NAME="Broken AUR"
  AERO7_APP_SUPPORTED_SESSION="wayland"
  AERO7_APP_AVAILABLE="yes"
  AERO7_APP_EXPERIMENTAL="no"
  AERO7_APP_INSTALL_KIND="aur"
  AERO7_APP_AUR_PACKAGE="broken-aur"
  AERO7_APP_FATAL="no"
  AERO7_APP_VALIDATE_COMMAND="true"
  aero7_yay_install_packages() { return 1; }
  if aero7_app_install_current_recipe >/dev/null 2>&1; then
    fail "application recipe reported success after failed AUR install"
  fi
)

printf 'test-policy: ok\n'
