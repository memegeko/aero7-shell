#!/usr/bin/env bash

if [[ -n "${AERO7_BOOTLOADER_LOADED:-}" ]]; then
  return 0
fi
AERO7_BOOTLOADER_LOADED=1

aero7_root_path() {
  local path="$1"
  printf '%s%s\n' "${AERO7_TEST_ROOT:-}" "$path"
}

aero7_detect_bootloader() {
  local grub=0
  local systemd_boot=0

  [[ -f "$(aero7_root_path /etc/default/grub)" || -f "$(aero7_root_path /boot/grub/grub.cfg)" ]] && grub=1
  [[ -f "$(aero7_root_path /boot/loader/loader.conf)" && -d "$(aero7_root_path /boot/loader/entries)" ]] && systemd_boot=1

  if [[ "$grub" -eq 1 && "$systemd_boot" -eq 1 ]]; then
    printf 'ambiguous\n'
  elif [[ "$grub" -eq 1 ]]; then
    printf 'grub\n'
  elif [[ "$systemd_boot" -eq 1 ]]; then
    printf 'systemd-boot\n'
  else
    printf 'unsupported\n'
  fi
}

aero7_merge_kernel_params() {
  local existing="$1"
  shift
  aero7_words_add_unique "$existing" "$@"
}

aero7_update_grub_cmdline_file() {
  local input="$1"
  local output="$2"
  shift 2
  local line value merged wrote=0
  : >"$output"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
      merged="$(aero7_merge_kernel_params "$value" "$@")"
      printf 'GRUB_CMDLINE_LINUX_DEFAULT="%s"\n' "$merged" >>"$output"
      wrote=1
    else
      printf '%s\n' "$line" >>"$output"
    fi
  done <"$input"
  if [[ "$wrote" -eq 0 ]]; then
    printf 'GRUB_CMDLINE_LINUX_DEFAULT="%s"\n' "$(aero7_merge_kernel_params "" "$@")" >>"$output"
  fi
}

aero7_validate_grub_default_file() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$file" || return 1
}

aero7_update_systemd_boot_entry_file() {
  local input="$1"
  local output="$2"
  shift 2
  local line value merged wrote=0
  : >"$output"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^options[[:space:]]+(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      merged="$(aero7_merge_kernel_params "$value" "$@")"
      printf 'options %s\n' "$merged" >>"$output"
      wrote=1
    else
      printf '%s\n' "$line" >>"$output"
    fi
  done <"$input"
  [[ "$wrote" -eq 1 ]]
}

aero7_validate_systemd_boot_entry_file() {
  local file="$1"
  [[ -s "$file" ]] || return 1
  grep -q '^linux[[:space:]]' "$file" || return 1
  grep -q '^initrd[[:space:]]' "$file" || return 1
  grep -q '^options[[:space:]]' "$file" || return 1
}

aero7_configure_bootloader_for_plymouth() {
  local bootloader
  bootloader="$(aero7_detect_bootloader)"
  aero7_state_set "detected_bootloader" "$bootloader"

  case "$bootloader" in
    grub)
      aero7_info "Detected GRUB."
      if aero7_dry_run; then
        aero7_info "Would merge quiet splash into GRUB_CMDLINE_LINUX_DEFAULT and regenerate grub.cfg."
        return 0
      fi
      local source tmp
      source="/etc/default/grub"
      [[ -f "$source" ]] || aero7_die "GRUB config not found: $source"
      tmp="$(mktemp)"
      trap 'rm -f -- "$tmp"' RETURN
      aero7_update_grub_cmdline_file "$source" "$tmp" quiet splash
      aero7_replace_file_safely "$source" "$tmp" "grub" "aero7_validate_grub_default_file"
      rm -f -- "$tmp"
      trap - RETURN
      if aero7_have grub-mkconfig; then
        aero7_sudo_run grub-mkconfig -o /boot/grub/grub.cfg
      else
        aero7_die "grub-mkconfig is required but unavailable."
      fi
      ;;
    systemd-boot)
      aero7_info "Detected systemd-boot."
      if aero7_dry_run; then
        aero7_info "Would merge quiet splash into normal systemd-boot entries."
        return 0
      fi
      local entry tmp_entry
      for entry in /boot/loader/entries/*.conf; do
        [[ -f "$entry" ]] || continue
        case "$(basename -- "$entry")" in
          *fallback*|*Fallback*|*recovery*|*Recovery*) continue ;;
        esac
        tmp_entry="$(mktemp)"
        trap 'rm -f -- "$tmp_entry"' RETURN
        aero7_update_systemd_boot_entry_file "$entry" "$tmp_entry" quiet splash
        aero7_replace_file_safely "$entry" "$tmp_entry" "systemd-boot" "aero7_validate_systemd_boot_entry_file"
        rm -f -- "$tmp_entry"
        trap - RETURN
      done
      ;;
    ambiguous)
      if aero7_dry_run; then
        aero7_warn "Both GRUB and systemd-boot configuration were detected. A real install would stop before boot changes."
        return 0
      fi
      aero7_die "Both GRUB and systemd-boot configuration were detected. Refusing boot changes until the active bootloader is clear."
      ;;
    *)
      if aero7_dry_run; then
        aero7_warn "No supported bootloader detected. A real install would stop before boot changes."
        return 0
      fi
      aero7_die "No supported bootloader detected; stopping before boot changes."
      ;;
  esac
}
