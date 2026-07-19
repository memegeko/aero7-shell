#!/usr/bin/env bash
set -Eeuo pipefail

AERO7_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export AERO7_PROJECT_ROOT

source "$AERO7_PROJECT_ROOT/lib/common.sh"
source "$AERO7_PROJECT_ROOT/lib/logging.sh"
source "$AERO7_PROJECT_ROOT/lib/state.sh"
source "$AERO7_PROJECT_ROOT/lib/packages.sh"
source "$AERO7_PROJECT_ROOT/lib/aur.sh"
source "$AERO7_PROJECT_ROOT/lib/applications.sh"
source "$AERO7_PROJECT_ROOT/lib/validation.sh"
source "$AERO7_PROJECT_ROOT/lib/bootloader.sh"
source "$AERO7_PROJECT_ROOT/lib/initramfs.sh"
source "$AERO7_PROJECT_ROOT/lib/systemd.sh"

aero7_init_paths
aero7_logging_init update
aero7_sudo_keepalive_start
trap 'aero7_sudo_keepalive_stop' EXIT

latest=""
if aero7_have curl; then
  latest="$(curl -fsSL "https://api.github.com/repos/${AERO7_REPOSITORY}/releases/latest" 2>/dev/null | awk -F\" '/"tag_name"/ { print $4; exit }' || true)"
fi

printf 'Installed Aero7-shell: %s\n' "$AERO7_VERSION"
printf 'Available release:     %s\n' "${latest:-unknown}"

if [[ -z "$latest" ]]; then
  aero7_warn "Could not fetch release metadata; skipping self-update."
else
  aero7_info "Self-update download is handled by the release bootstrap path for version $latest."
fi

if aero7_have yay && ! aero7_is_root; then
  aur_packages=()
  mapfile -t aur_packages < <(aero7_load_package_file "$AERO7_CONFIG_DIR/aur-packages.conf")
  aero7_yay_install_packages "${aur_packages[@]}"
else
  aero7_warn "yay is unavailable or current user is root; skipping AUR update."
fi

aero7_apps_status >/dev/null
aero7_doctor || true
