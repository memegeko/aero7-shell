#!/usr/bin/env bash

if [[ -n "${AERO7_INITRAMFS_LOADED:-}" ]]; then
  return 0
fi
AERO7_INITRAMFS_LOADED=1

aero7_detect_initramfs() {
  local mk=0
  local dr=0
  [[ -f "$(aero7_root_path /etc/mkinitcpio.conf)" || -d "$(aero7_root_path /etc/mkinitcpio.conf.d)" ]] && mk=1
  [[ -f "$(aero7_root_path /etc/dracut.conf)" || -d "$(aero7_root_path /etc/dracut.conf.d)" ]] && dr=1
  if [[ "$mk" -eq 1 && "$dr" -eq 1 ]]; then
    printf 'ambiguous\n'
  elif [[ "$mk" -eq 1 ]]; then
    printf 'mkinitcpio\n'
  elif [[ "$dr" -eq 1 ]]; then
    printf 'dracut\n'
  else
    printf 'unsupported\n'
  fi
}

aero7_mkinitcpio_hooks_with_plymouth() {
  local line="$1"
  local inside before after
  if [[ ! "$line" =~ ^([[:space:]]*HOOKS=)\((.*)\)(.*)$ ]]; then
    printf '%s\n' "$line"
    return 0
  fi

  before="${BASH_REMATCH[1]}"
  inside="${BASH_REMATCH[2]}"
  after="${BASH_REMATCH[3]}"

  local original=()
  local filtered=()
  local hook
  read -r -a original <<<"$inside"
  for hook in "${original[@]}"; do
    case "$hook" in
      kms|plymouth) ;;
      *) filtered+=("$hook") ;;
    esac
  done

  local result=()
  local inserted=0
  for hook in "${filtered[@]}"; do
    result+=("$hook")
    if [[ "$hook" == "modconf" ]]; then
      result+=(kms plymouth)
      inserted=1
    fi
  done
  if [[ "$inserted" -eq 0 ]]; then
    result=(kms plymouth "${filtered[@]}")
  fi

  printf '%s(%s)%s\n' "$before" "$(aero7_shell_join "${result[@]}")" "$after"
}

aero7_update_mkinitcpio_file() {
  local input="$1"
  local output="$2"
  local line
  : >"$output"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*HOOKS= ]]; then
      aero7_mkinitcpio_hooks_with_plymouth "$line" >>"$output"
    else
      printf '%s\n' "$line" >>"$output"
    fi
  done <"$input"
}

aero7_validate_mkinitcpio_file() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  grep -q '^[[:space:]]*HOOKS=(' "$file" || return 1
}

aero7_validate_dracut_plymouth_dropin() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  grep -q 'add_dracutmodules+=" plymouth "' "$file" || return 1
}

aero7_run_mkinitcpio_rebuild() {
  aero7_sudo_run mkinitcpio -P
}

aero7_run_dracut_rebuild() {
  aero7_sudo_run dracut --regenerate-all --force
}

aero7_configure_initramfs_for_plymouth() {
  local initramfs
  initramfs="$(aero7_detect_initramfs)"
  aero7_state_set "detected_initramfs" "$initramfs"

  case "$initramfs" in
    mkinitcpio)
      aero7_info "Detected mkinitcpio."
      if aero7_dry_run; then
        aero7_info "Would insert kms and plymouth hooks and run mkinitcpio -P."
        return 0
      fi
      local source tmp backup
      source="${AERO7_MKINITCPIO_CONF:-/etc/mkinitcpio.conf}"
      [[ -f "$source" ]] || aero7_die "mkinitcpio config not found: $source"
      tmp="$(mktemp)"
      trap 'rm -f -- "$tmp"' RETURN
      aero7_update_mkinitcpio_file "$source" "$tmp"
      aero7_replace_file_safely "$source" "$tmp" "mkinitcpio" "aero7_validate_mkinitcpio_file"
      backup="${AERO7_LAST_FILE_BACKUP:-}"
      rm -f -- "$tmp"
      trap - RETURN
      if ! aero7_run_mkinitcpio_rebuild; then
        if [[ -n "$backup" ]]; then
          aero7_warn "mkinitcpio rebuild failed; restoring previous mkinitcpio configuration."
          aero7_restore_file_backup "$backup" "$source"
        fi
        return 1
      fi
      ;;
    dracut)
      aero7_info "Detected dracut."
      if aero7_dry_run; then
        aero7_info "Would create /etc/dracut.conf.d/aero7-plymouth.conf and regenerate initramfs images."
        return 0
      fi
      local dropin tmp_dropin backup existed
      dropin="${AERO7_DRACUT_DROPIN:-/etc/dracut.conf.d/aero7-plymouth.conf}"
      tmp_dropin="$(mktemp)"
      trap 'rm -f -- "$tmp_dropin"' RETURN
      printf 'add_dracutmodules+=" plymouth "\n' >"$tmp_dropin"
      backup=""
      existed=0
      if [[ -f "$dropin" ]]; then
        existed=1
        aero7_replace_file_safely "$dropin" "$tmp_dropin" "dracut" "aero7_validate_dracut_plymouth_dropin"
        backup="${AERO7_LAST_FILE_BACKUP:-}"
      else
        aero7_validate_dracut_plymouth_dropin "$tmp_dropin" || aero7_die "Generated dracut drop-in failed validation."
        if ! aero7_dry_run; then
          aero7_sudo_run install -D -m 0644 "$tmp_dropin" "$dropin"
          aero7_state_append "modified_files" "$dropin"
        else
          aero7_info "Would install $dropin."
        fi
      fi
      rm -f -- "$tmp_dropin"
      trap - RETURN
      if ! aero7_run_dracut_rebuild; then
        aero7_warn "dracut regeneration failed; restoring previous dracut configuration."
        if [[ "$existed" -eq 1 && -n "$backup" ]]; then
          aero7_restore_file_backup "$backup" "$dropin"
        elif [[ "$existed" -eq 0 && -f "$dropin" ]]; then
          aero7_safe_remove_file "$dropin" "/etc/dracut.conf.d"
        fi
        return 1
      fi
      ;;
    ambiguous)
      if aero7_dry_run; then
        aero7_warn "Both mkinitcpio and dracut configuration were detected. A real install would stop before initramfs changes."
        return 0
      fi
      aero7_die "Both mkinitcpio and dracut configuration were detected. Refusing initramfs changes until the active implementation is clear."
      ;;
    *)
      if aero7_dry_run; then
        aero7_warn "No supported initramfs implementation detected. A real install would stop before initramfs changes."
        return 0
      fi
      aero7_die "No supported initramfs implementation detected; stopping before boot changes."
      ;;
  esac
  aero7_state_set "reboot_recommended" "yes"
}
