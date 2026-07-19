#!/usr/bin/env bash
set -Eeuo pipefail

AERO7_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export AERO7_PROJECT_ROOT

source "$AERO7_PROJECT_ROOT/lib/common.sh"
source "$AERO7_PROJECT_ROOT/lib/logging.sh"
source "$AERO7_PROJECT_ROOT/lib/ui.sh"
source "$AERO7_PROJECT_ROOT/lib/prompts.sh"
source "$AERO7_PROJECT_ROOT/lib/state.sh"
source "$AERO7_PROJECT_ROOT/lib/backup.sh"

AERO7_KEEP_PACKAGES=0
AERO7_KEEP_APPS=0
AERO7_RESTORE_BACKUP=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --keep-packages) AERO7_KEEP_PACKAGES=1 ;;
    --keep-apps) AERO7_KEEP_APPS=1 ;;
    --restore-backup) AERO7_RESTORE_BACKUP=1 ;;
    --help)
      cat <<'EOF'
Usage: ./uninstall.sh [--keep-packages] [--keep-apps] [--restore-backup]
EOF
      exit 0
      ;;
    *) aero7_die "Unknown uninstall option: $1" ;;
  esac
  shift
done

aero7_init_paths
aero7_logging_init uninstall
aero7_title

cat <<EOF
Uninstall will remove Aero7-shell commands, assets, and Aero7-specific configuration.
It will not remove Plasma, NetworkManager, audio services, personal files, or backups.
Package removal is conservative and skipped by default unless tracked state confirms ownership.
EOF

aero7_confirm "Proceed with Aero7-shell uninstall?" "no" || exit 0

aero7_sudo_keepalive_start
trap 'aero7_sudo_keepalive_stop' EXIT

for command in aero7 aero7-dir aero7-ipconfig aero7-systeminfo aero7-winver; do
  if [[ -e "$AERO7_SYSTEM_BIN_DIR/$command" ]]; then
    aero7_safe_remove_file "$AERO7_SYSTEM_BIN_DIR/$command" "$AERO7_SYSTEM_BIN_DIR"
  fi
done

if [[ -d "$AERO7_ASSET_DIR" ]]; then
  aero7_safe_remove_tree "$AERO7_ASSET_DIR" "/usr/share"
fi
if [[ -e /etc/sddm.conf.d/aero7-shell.conf ]]; then
  aero7_safe_remove_file /etc/sddm.conf.d/aero7-shell.conf /etc/sddm.conf.d
fi

if [[ "$AERO7_RESTORE_BACKUP" -eq 1 ]]; then
  latest="$(aero7_latest_backup || true)"
  [[ -n "$latest" ]] || aero7_die "No backups available to restore."
  aero7_restore_backup "$latest"
fi

if [[ "$AERO7_KEEP_PACKAGES" -eq 0 ]]; then
  aero7_warn "Automatic package removal is not enabled until install ownership tracking has been reviewed in a VM."
fi

if [[ "$AERO7_KEEP_APPS" -eq 0 ]]; then
  aero7_warn "Application source/build caches are preserved by default. Remove $AERO7_CACHE_DIR manually after reviewing it."
fi

printf 'Aero7-shell uninstall completed. Backups were preserved.\n'
