#!/usr/bin/env bash

if [[ -n "${AERO7_BACKUP_LOADED:-}" ]]; then
  return 0
fi
AERO7_BACKUP_LOADED=1

aero7_backup_root() {
  if aero7_dry_run; then
    printf '%s\n' "$AERO7_USER_STATE_DIR/dry-run/backups"
  else
    printf '%s\n' "$AERO7_SYSTEM_STATE_DIR/backups"
  fi
}

aero7_backup_default_paths() {
  aero7_detect_user
  cat <<EOF
$AERO7_HOME/.config/kdeglobals
$AERO7_HOME/.config/kwinrc
$AERO7_HOME/.config/plasmarc
$AERO7_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc
$AERO7_HOME/.config/ksmserverrc
$AERO7_HOME/.config/dolphinrc
$AERO7_HOME/.config/kglobalshortcutsrc
$AERO7_HOME/.local/share/plasma
$AERO7_HOME/.local/share/kwin
/etc/sddm.conf
/etc/sddm.conf.d
/etc/mkinitcpio.conf
/etc/mkinitcpio.conf.d
/etc/dracut.conf
/etc/dracut.conf.d
/etc/default/grub
/boot/grub/grub.cfg
/boot/loader/loader.conf
/boot/loader/entries
EOF
}

aero7_backup_manifest_line() {
  local source="$1"
  local dest="$2"
  local owner group mode checksum
  owner="$(stat -c '%U' "$source" 2>/dev/null || printf 'unknown')"
  group="$(stat -c '%G' "$source" 2>/dev/null || printf 'unknown')"
  mode="$(stat -c '%a' "$source" 2>/dev/null || printf 'unknown')"
  checksum=""
  if [[ -f "$source" && -r "$source" ]]; then
    checksum="$(sha256sum "$source" | awk '{print $1}')"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$source" "$dest" "$owner" "$group" "$mode" "$checksum"
}

aero7_create_backup() {
  aero7_init_paths
  local id root dir manifest source rel dest
  id="$(date +%Y%m%d-%H%M%S)"
  root="$(aero7_backup_root)"
  dir="$root/$id"
  manifest="$dir/manifest.tsv"

  if aero7_dry_run; then
    mkdir -p -- "$dir"
  else
    aero7_sudo_run install -d -m 0755 "$dir"
  fi

  if ! aero7_dry_run; then
    printf 'source\tbackup\towner\tgroup\tmode\tsha256\n' | aero7_write_root_text "$manifest" 0644
  else
    printf 'source\tbackup\towner\tgroup\tmode\tsha256\n' >"$manifest"
  fi

  while IFS= read -r source; do
    [[ -e "$source" ]] || continue
    rel="${source#/}"
    dest="$dir/files/$rel"
    if aero7_dry_run; then
      mkdir -p -- "$(dirname -- "$dest")"
      aero7_backup_manifest_line "$source" "$dest" >>"$manifest"
    else
      aero7_sudo_run install -d -m 0755 "$(dirname -- "$dest")"
      aero7_sudo_run cp -a -- "$source" "$dest"
      aero7_backup_manifest_line "$source" "$dest" | aero7_sudo tee -a "$manifest" >/dev/null
    fi
  done < <(aero7_backup_default_paths)

  aero7_state_set "backup_id" "$id"
  aero7_state_set "backup_path" "$dir"
  aero7_info "Backup created: $id"
}

aero7_list_backups() {
  aero7_init_paths
  local root
  root="$(aero7_backup_root)"
  [[ -d "$root" ]] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

aero7_latest_backup() {
  aero7_list_backups | tail -n 1
}

aero7_restore_backup() {
  local backup_id="$1"
  local root dir manifest source backup
  aero7_init_paths
  root="$(aero7_backup_root)"
  dir="$root/$backup_id"
  manifest="$dir/manifest.tsv"
  [[ -r "$manifest" ]] || aero7_die "Backup manifest not found: $manifest"

  printf 'Aero7-shell will restore files from backup %s:\n' "$backup_id"
  awk -F '\t' 'NR > 1 { print "  " $2 " -> " $1 }' "$manifest"
  aero7_confirm "Proceed with restore?" "no" || return 1

  while IFS=$'\t' read -r source backup _owner _group _mode _checksum; do
    [[ "$source" == "source" ]] && continue
    [[ -e "$backup" ]] || continue
    aero7_sudo_run install -d -m 0755 "$(dirname -- "$source")"
    aero7_sudo_run cp -a -- "$backup" "$source"
  done <"$manifest"
}

