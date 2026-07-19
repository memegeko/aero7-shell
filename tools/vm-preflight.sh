#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export AERO7_PROJECT_ROOT="$repo_root"

# Runtime path is resolved relative to this repository checkout.
# shellcheck disable=SC1091
source "$repo_root/lib/common.sh"
# shellcheck disable=SC1091
source "$repo_root/lib/bootloader.sh"
# shellcheck disable=SC1091
source "$repo_root/lib/initramfs.sh"
# shellcheck disable=SC1091
source "$repo_root/lib/plasma.sh"

aero7_init_paths

status_line() {
  printf '%-34s %s\n' "$1" "$2"
}

os_pretty="unknown"
if [[ -r /etc/os-release ]]; then
  os_pretty="$(awk -F= '$1 == "PRETTY_NAME" { gsub(/"/, "", $2); print $2 }' /etc/os-release)"
fi

network="unknown"
if aero7_have ping && ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
  network="OK"
else
  network="FAILED"
fi

sudo_status="unavailable"
if aero7_have sudo && sudo -n true >/dev/null 2>&1; then
  sudo_status="passwordless/currently cached"
elif aero7_have sudo; then
  sudo_status="installed; may prompt"
fi

virt="unknown"
if aero7_have systemd-detect-virt; then
  if ! virt="$(systemd-detect-virt 2>/dev/null)"; then
    virt="none"
  fi
fi

gpu="unknown"
if aero7_have lspci; then
  gpu="$(lspci | awk -F': ' '/VGA|3D|Display/ { print $2; exit }')"
fi

kernel="$(uname -r)"
plasma="not installed"
if aero7_have pacman && pacman -Q plasma-workspace >/dev/null 2>&1; then
  plasma="installed"
fi

sddm="unknown"
if aero7_have systemctl; then
  sddm="$(systemctl is-enabled sddm.service 2>/dev/null || printf 'disabled')"
fi

wayland_session="missing"
if aero7_validate_plasma_wayland_session; then
  wayland_session="present"
fi

status_line "Arch Linux" "$os_pretty"
status_line "Current user" "$(id -un)"
status_line "sudo availability" "$sudo_status"
status_line "Network" "$network"
status_line "Free disk space" "$(df -h / | awk 'NR == 2 { print $4 " available on /" }')"
status_line "Virtualization" "$virt"
status_line "GPU" "${gpu:-unknown}"
status_line "Bootloader" "$(aero7_detect_bootloader)"
status_line "Initramfs" "$(aero7_detect_initramfs)"
status_line "Installed kernel" "$kernel"
status_line "Plasma" "$plasma"
status_line "SDDM enabled" "$sddm"
status_line "Wayland session file" "$wayland_session"

if aero7_is_arch_linux && [[ "$network" == "OK" && "$wayland_session" == "present" || "$plasma" == "not installed" ]]; then
  status_line "First VM test suitability" "likely suitable"
else
  status_line "First VM test suitability" "review warnings before install"
fi
