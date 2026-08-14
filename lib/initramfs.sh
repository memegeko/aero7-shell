#!/usr/bin/env bash

if [[ -n "${AERO7_INITRAMFS_LOADED:-}" ]]; then
  return 0
fi
AERO7_INITRAMFS_LOADED=1

AERO7_PLYMOUTH_VISTA_REPOSITORY="${AERO7_PLYMOUTH_VISTA_REPOSITORY:-https://github.com/furkrn/PlymouthVista.git}"
AERO7_PLYMOUTH_VISTA_REF="${AERO7_PLYMOUTH_VISTA_REF:-e2b9605a7b4d649bb0e314cce8bbe9912633cfef}"

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

aero7_mkinitcpio_config_has_plymouth() {
  local source line inside hook
  local -a hooks=()
  source="${AERO7_MKINITCPIO_CONF:-$(aero7_root_path /etc/mkinitcpio.conf)}"
  [[ -f "$source" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*HOOKS=\((.*)\) ]] || continue
    inside="${BASH_REMATCH[1]}"
    read -r -a hooks <<<"$inside"
    for hook in "${hooks[@]}"; do
      [[ "$hook" == "plymouth" ]] && return 0
    done
  done <"$source"
  return 1
}

aero7_dracut_config_has_plymouth() {
  local dropin
  dropin="${AERO7_DRACUT_DROPIN:-$(aero7_root_path /etc/dracut.conf.d/aero7-plymouth.conf)}"
  [[ -f "$dropin" ]] || return 1
  aero7_validate_dracut_plymouth_dropin "$dropin"
}

aero7_initramfs_config_has_plymouth() {
  local initramfs
  initramfs="$(aero7_detect_initramfs)"
  case "$initramfs" in
    mkinitcpio) aero7_mkinitcpio_config_has_plymouth ;;
    dracut) aero7_dracut_config_has_plymouth ;;
    *) return 1 ;;
  esac
}

aero7_initramfs_image_contains_plymouth() {
  local image boot_dir uki_dir found=1
  local -a uki_dirs=()
  boot_dir="$(aero7_root_path /boot)"
  for image in "$boot_dir"/initramfs*.img; do
    [[ -f "$image" ]] || continue
    if lsinitcpio "$image" 2>/dev/null | grep -Eq '(^|/)hooks/plymouth$|(^|/)usr/bin/plymouthd$'; then
      found=0
      break
    fi
  done

  # mkinitcpio can embed the initramfs in a unified kernel image instead of
  # writing initramfs*.img. Support the conventional ESP mount locations. In a
  # real install the ESP can be root-only, so use the already-authorized sudo
  # session; test roots remain directly inspectable without privilege.
  uki_dirs=(
    "$(aero7_root_path /boot/EFI/Linux)"
    "$(aero7_root_path /efi/EFI/Linux)"
    "$(aero7_root_path /boot/efi/EFI/Linux)"
  )
  if [[ "$found" -ne 0 && -n "${AERO7_TEST_ROOT:-}" ]]; then
    for uki_dir in "${uki_dirs[@]}"; do
      for image in "$uki_dir"/*.efi; do
        [[ -f "$image" ]] || continue
        if lsinitcpio "$image" 2>/dev/null | grep -Eq '(^|/)hooks/plymouth$|(^|/)usr/bin/plymouthd$'; then
          found=0
          break 2
        fi
      done
    done
  elif [[ "$found" -ne 0 ]] && aero7_have sudo; then
    while IFS= read -r image; do
      [[ -n "$image" ]] || continue
      if sudo -n lsinitcpio "$image" 2>/dev/null | grep -Eq '(^|/)hooks/plymouth$|(^|/)usr/bin/plymouthd$'; then
        found=0
        break
      fi
    done < <(sudo -n find /boot/EFI/Linux /efi/EFI/Linux /boot/efi/EFI/Linux \
      -maxdepth 1 -type f -name '*.efi' -print 2>/dev/null || true)
  fi
  return "$found"
}

aero7_plymouth_config_path() {
  printf '%s\n' "${AERO7_PLYMOUTH_CONF:-$(aero7_root_path /etc/plymouth/plymouthd.conf)}"
}

aero7_plymouth_hold_dropin_path() {
  printf '%s\n' "${AERO7_PLYMOUTH_HOLD_DROPIN:-$(aero7_root_path /etc/systemd/system/plymouth-quit.service.d/aero7-hold.conf)}"
}

aero7_plymouth_theme_dir() {
  printf '%s\n' "${AERO7_PLYMOUTH_THEME_DIR:-$(aero7_root_path /usr/share/plymouth/themes/PlymouthVista)}"
}

aero7_validate_plymouth_vista_source() {
  local source_dir="$1"
  [[ -s "$source_dir/LICENSE" ]] || return 1
  [[ -s "$source_dir/PlymouthVista.plymouth" ]] || return 1
  [[ -x "$source_dir/compile.sh" ]] || return 1
  [[ -x "$source_dir/pv_conf.sh" ]] || return 1
  [[ -s "$source_dir/src/boot7.sp" ]] || return 1
  [[ -s "$source_dir/src/main.sp" ]] || return 1
  [[ -s "$source_dir/images/flag0.png" ]] || return 1
  [[ -s "$source_dir/images/flag104.png" ]] || return 1
  grep -Fxq 'ModuleName=script' "$source_dir/PlymouthVista.plymouth" || return 1
  grep -Fq 'SevenBootScreenNew' "$source_dir/src/boot7.sp"
}

aero7_validate_installed_plymouth_vista_theme() {
  local theme_dir
  theme_dir="$(aero7_plymouth_theme_dir)"
  [[ -s "$theme_dir/LICENSE" ]] || return 1
  [[ -s "$theme_dir/PlymouthVista.plymouth" ]] || return 1
  [[ -s "$theme_dir/PlymouthVista.script" ]] || return 1
  [[ -s "$theme_dir/images/flag0.png" ]] || return 1
  [[ -s "$theme_dir/images/flag104.png" ]] || return 1
  grep -Fxq 'ModuleName=script' "$theme_dir/PlymouthVista.plymouth" || return 1
  grep -Fq 'global.UseLegacyBootScreen = 0;' "$theme_dir/PlymouthVista.script" || return 1
  grep -Fq 'global.AuthuiStyle = "7";' "$theme_dir/PlymouthVista.script"
}

aero7_plymouth_vista_source_dir() {
  printf '%s/sources/PlymouthVista-%s\n' "$AERO7_CACHE_DIR" "${AERO7_PLYMOUTH_VISTA_REF:0:12}"
}

aero7_fetch_plymouth_vista_source() {
  local source_dir remote head
  source_dir="$(aero7_plymouth_vista_source_dir)"

  if aero7_dry_run; then
    aero7_info "Would download PlymouthVista revision $AERO7_PLYMOUTH_VISTA_REF from $AERO7_PLYMOUTH_VISTA_REPOSITORY."
    return 0
  fi

  aero7_have git || aero7_die "git is required to download PlymouthVista."
  aero7_user_run install -d -m 0755 "$AERO7_CACHE_DIR/sources"
  if [[ ! -d "$source_dir/.git" ]]; then
    [[ ! -e "$source_dir" ]] || aero7_die "PlymouthVista cache path exists but is not a Git checkout: $source_dir"
    aero7_user_run git init "$source_dir"
  fi

  remote="$(git -C "$source_dir" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$remote" ]]; then
    aero7_user_run git -C "$source_dir" remote add origin "$AERO7_PLYMOUTH_VISTA_REPOSITORY"
  elif [[ "$remote" != "$AERO7_PLYMOUTH_VISTA_REPOSITORY" ]]; then
    aero7_die "PlymouthVista cache uses an unexpected upstream URL: $remote"
  fi

  aero7_user_run git -C "$source_dir" fetch --depth 1 origin "$AERO7_PLYMOUTH_VISTA_REF"
  aero7_user_run git -C "$source_dir" checkout --detach "$AERO7_PLYMOUTH_VISTA_REF"
  head="$(git -C "$source_dir" rev-parse HEAD 2>/dev/null || true)"
  [[ "$head" == "$AERO7_PLYMOUTH_VISTA_REF" ]] || aero7_die "PlymouthVista revision verification failed."
  aero7_validate_plymouth_vista_source "$source_dir" || aero7_die "Downloaded PlymouthVista source failed validation."
}

aero7_configure_plymouth_vista_script() {
  local source_dir="$1"
  local script="$source_dir/PlymouthVista.script"
  local old_theme="$2"
  local key value
  local -a settings=(
    UseLegacyBootScreen 0
    UseShadow 1
    AuthuiStyle 7
    Pref 3
    UseHibernation 0
    DisableWall 0
    BootSlowdown 0
    OldPlymouthTheme "$old_theme"
  )

  # shellcheck disable=SC2016
  aero7_user_run bash -lc 'cd -- "$1" && ./compile.sh' _ "$source_dir"
  [[ -s "$script" ]] || aero7_die "PlymouthVista compilation did not produce PlymouthVista.script."

  while [[ "${#settings[@]}" -gt 0 ]]; do
    key="${settings[0]}"
    value="${settings[1]}"
    settings=("${settings[@]:2}")
    aero7_user_run "$source_dir/pv_conf.sh" -s "$key" -v "$value" -i "$script"
  done
}

aero7_generate_plymouth_vista_text_images() {
  local source_dir="$1"
  local font_file font_family generator

  aero7_have magick || aero7_die "ImageMagick is required for the PlymouthVista Windows 7 variant."
  font_file="$(fc-match --format='%{file}' 'Segoe UI' 2>/dev/null || true)"
  font_family="$(fc-match --format='%{family[0]}' 'Segoe UI' 2>/dev/null || true)"
  [[ -f "$font_file" ]] || aero7_die "No system font is available for PlymouthVista text rendering."
  if [[ "$font_family" != "Segoe UI" ]]; then
    aero7_warn "Segoe UI is not installed; PlymouthVista will use the system fallback font $font_family."
  fi

  generator="$source_dir/.aero7-gen-blur.sh"
  awk -v font="$font_file" '
    /^FONT=/ { print "FONT=\"" font "\""; next }
    { print }
  ' "$source_dir/gen_blur.sh" >"$generator"
  chmod 0755 "$generator"
  # shellcheck disable=SC2016
  aero7_user_run bash -lc 'cd -- "$1" && bash "$2"' _ "$source_dir" "$generator"
}

aero7_install_plymouth_theme() {
  local source_dir theme_dir old_theme
  source_dir="$(aero7_plymouth_vista_source_dir)"
  theme_dir="$(aero7_plymouth_theme_dir)"

  if aero7_dry_run; then
    aero7_fetch_plymouth_vista_source
    aero7_info "Would configure and install PlymouthVista in Windows 7 mode at $theme_dir."
    return 0
  fi

  aero7_fetch_plymouth_vista_source
  old_theme="$(plymouth-set-default-theme 2>/dev/null || printf '%s\n' spinner)"
  aero7_configure_plymouth_vista_script "$source_dir" "$old_theme"
  aero7_generate_plymouth_vista_text_images "$source_dir"

  if [[ -d "$theme_dir" ]]; then
    aero7_safe_remove_tree "$theme_dir" "/usr/share/plymouth/themes"
  fi
  aero7_sudo_run install -d -m 0755 "$theme_dir"
  aero7_sudo_run install -m 0644 "$source_dir/LICENSE" "$theme_dir/LICENSE"
  aero7_sudo_run install -m 0644 "$source_dir/PlymouthVista.plymouth" "$theme_dir/PlymouthVista.plymouth"
  aero7_sudo_run install -m 0644 "$source_dir/PlymouthVista.script" "$theme_dir/PlymouthVista.script"
  aero7_sudo_run cp -a "$source_dir/images" "$theme_dir/"
  aero7_validate_installed_plymouth_vista_theme || aero7_die "Installed PlymouthVista theme failed validation."
  aero7_state_append "modified_files" "$theme_dir"
}

aero7_update_plymouth_config_file() {
  local input="$1"
  local output="$2"

  awk '
    BEGIN {
      in_daemon = 0
      saw_daemon = 0
      wrote_delay = 0
    }
    /^\[[^]]+\][[:space:]]*$/ {
      if (in_daemon && !wrote_delay) {
        print "ShowDelay=0"
        wrote_delay = 1
      }
      in_daemon = ($0 == "[Daemon]")
      if (in_daemon) {
        saw_daemon = 1
        wrote_delay = 0
      }
      print
      next
    }
    in_daemon && /^[[:space:]]*ShowDelay[[:space:]]*=/ {
      if (!wrote_delay) {
        print "ShowDelay=0"
        wrote_delay = 1
      }
      next
    }
    { print }
    END {
      if (in_daemon && !wrote_delay) {
        print "ShowDelay=0"
      } else if (!saw_daemon) {
        print ""
        print "[Daemon]"
        print "ShowDelay=0"
      }
    }
  ' "$input" >"$output"
}

aero7_validate_plymouth_config() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  awk '
    /^\[Daemon\][[:space:]]*$/ { in_daemon = 1; next }
    /^\[[^]]+\][[:space:]]*$/ { in_daemon = 0 }
    in_daemon && /^[[:space:]]*ShowDelay[[:space:]]*=[[:space:]]*0[[:space:]]*$/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

aero7_validate_plymouth_hold_dropin() {
  local file="$1"
  local seconds="${AERO7_PLYMOUTH_HOLD_SECONDS:-5}"
  [[ -s "$file" ]] || return 1
  grep -Fxq "ExecStartPre=/usr/bin/sleep $seconds" "$file"
}

aero7_plymouth_visibility_configured() {
  local config dropin
  config="$(aero7_plymouth_config_path)"
  dropin="$(aero7_plymouth_hold_dropin_path)"
  aero7_validate_plymouth_config "$config" && aero7_validate_plymouth_hold_dropin "$dropin"
}

aero7_configure_plymouth_visibility() {
  local seconds="${AERO7_PLYMOUTH_HOLD_SECONDS:-5}"
  local config dropin config_tmp dropin_tmp backup
  [[ "$seconds" =~ ^[0-9]+$ ]] || aero7_die "Invalid Plymouth hold duration: $seconds"

  config="${AERO7_PLYMOUTH_CONF:-/etc/plymouth/plymouthd.conf}"
  dropin="${AERO7_PLYMOUTH_HOLD_DROPIN:-/etc/systemd/system/plymouth-quit.service.d/aero7-hold.conf}"

  if aero7_dry_run; then
    aero7_info "Would show Plymouth immediately and keep the splash visible for at least $seconds seconds."
    return 0
  fi

  [[ -f "$config" ]] || aero7_die "Plymouth configuration not found: $config"
  config_tmp="$(mktemp)" || return 1
  dropin_tmp="$(mktemp)" || {
    rm -f -- "$config_tmp"
    return 1
  }
  trap 'rm -f -- "$config_tmp" "$dropin_tmp"' RETURN

  aero7_update_plymouth_config_file "$config" "$config_tmp"
  aero7_replace_file_safely "$config" "$config_tmp" "plymouth" "aero7_validate_plymouth_config"
  backup="${AERO7_LAST_FILE_BACKUP:-}"
  printf '[Service]\nExecStartPre=/usr/bin/sleep %s\n' "$seconds" >"$dropin_tmp"
  aero7_validate_plymouth_hold_dropin "$dropin_tmp" || aero7_die "Generated Plymouth hold unit failed validation."
  aero7_sudo_run install -D -m 0644 "$dropin_tmp" "$dropin" || {
    [[ -n "$backup" ]] && aero7_restore_file_backup "$backup" "$config"
    return 1
  }
  aero7_state_append "modified_files" "$dropin"
  aero7_sudo_run systemctl daemon-reload

  rm -f -- "$config_tmp" "$dropin_tmp"
  trap - RETURN
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
