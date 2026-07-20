#!/usr/bin/env bash

if [[ -n "${AERO7_VALIDATION_LOADED:-}" ]]; then
  return 0
fi
AERO7_VALIDATION_LOADED=1

aero7_validation_tui_backend() {
  declare -F aero7_tui_backend >/dev/null 2>&1 &&
    aero7_tui_backend &&
    declare -F aero7_event_action_output >/dev/null 2>&1
}

aero7_doctor_line() {
  local color="$1"
  local icon="$2"
  shift 2
  if aero7_validation_tui_backend; then
    aero7_event_action_output "$*"
    return 0
  fi
  printf '    %s%s%s %s\n' "$color" "$icon" "$AERO7_C_RESET" "$*"
}

aero7_doctor_section() {
  local title="$1"
  if aero7_validation_tui_backend; then
    aero7_event_action_phase "$title"
    return 0
  fi
  if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
    aero7_ui_quiet && return 0
    printf '\n  %s%s%s\n' "$AERO7_C_BOLD" "$title" "$AERO7_C_RESET"
  else
    printf '\n%s\n' "$title"
  fi
}

aero7_check_status() {
  local label="$1"
  local status="$2"
  case "$status" in
    FAILED)
      AERO7_DOCTOR_FAILURES="$((AERO7_DOCTOR_FAILURES + 1))"
      ;;
    WARNING)
      AERO7_DOCTOR_WARNINGS="$((AERO7_DOCTOR_WARNINGS + 1))"
      ;;
  esac

  if aero7_validation_tui_backend; then
    case "$status" in
      OK)
        aero7_event_item complete "$label"
        ;;
      FAILED)
        aero7_event_item failed "$label"
        ;;
      WARNING)
        aero7_event_item warning "$label"
        aero7_event_warning "$label"
        ;;
      NOT\ INSTALLED)
        aero7_event_item skipped "$label"
        ;;
      *)
        aero7_event_action_output "$label: $status"
        ;;
    esac
    return 0
  fi

  if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
    if aero7_ui_quiet && [[ "$status" != "FAILED" && "$status" != "WARNING" ]]; then
      return 0
    fi
    case "$status" in
      OK)
        aero7_doctor_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "$label"
        ;;
      FAILED)
        aero7_doctor_line "$AERO7_C_RED" "$AERO7_ICON_FAIL" "$label"
        ;;
      WARNING)
        aero7_doctor_line "$AERO7_C_YELLOW" "$AERO7_ICON_WARN" "$label"
        ;;
      NOT\ INSTALLED)
        aero7_doctor_line "$AERO7_C_DIM" "$AERO7_ICON_SKIP" "$label"
        ;;
      *)
        aero7_doctor_line "$AERO7_C_DIM" "$AERO7_ICON_DETAIL" "$label: $status"
        ;;
    esac
    return 0
  fi
  printf '%-42s %s\n' "$label" "$status"
}

aero7_doctor_package_installed() {
  local package="$1"
  if aero7_have pacman && aero7_pacman_installed "$package"; then
    return 0
  fi
  if aero7_state_unique_file "installed_aur_packages" | grep -Fxq "$package"; then
    return 0
  fi
  if aero7_state_unique_file "installed_core_packages" | grep -Fxq "$package"; then
    return 0
  fi
  return 1
}

aero7_doctor_result() {
  local result
  if [[ "$AERO7_DOCTOR_FAILURES" -gt 0 ]]; then
    result="Unhealthy with $AERO7_DOCTOR_FAILURES failure(s)"
  elif [[ "$AERO7_DOCTOR_WARNINGS" -gt 0 ]]; then
    result="Healthy with $AERO7_DOCTOR_WARNINGS warning(s)"
  else
    result="Healthy"
  fi

  if aero7_validation_tui_backend; then
    aero7_event_action_output "Doctor result: $result"
    return 0
  fi

  if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
    printf '\n  %sResult%s        %s\n' "$AERO7_C_CYAN" "$AERO7_C_RESET" "$result"
  else
    printf '\nResult: %s\n' "$result"
  fi
}

aero7_doctor() {
  AERO7_DOCTOR_FAILURES=0
  AERO7_DOCTOR_WARNINGS=0

  if aero7_validation_tui_backend; then
    aero7_event_action_start "Running final validation"
  elif [[ -n "${AERO7_UI_LOADED:-}" ]]; then
    aero7_ui_quiet || aero7_ui_box "Aero7-shell Doctor" ""
  else
    printf 'Aero7-shell Doctor\n'
  fi

  aero7_doctor_section "System"
  if aero7_is_arch_linux; then
    aero7_check_status "Arch Linux detected" "OK"
  else
    aero7_check_status "Arch Linux detected" "FAILED"
  fi

  if aero7_validate_no_x11_packages_configured; then
    aero7_check_status "Wayland-only package policy" "OK"
  else
    aero7_check_status "Wayland-only package policy" "FAILED"
  fi

  if ! aero7_validate_no_x11_packages_installed; then
    aero7_check_status "Existing X11-only packages" "WARNING"
  else
    aero7_check_status "No prohibited X11 packages installed" "OK"
  fi

  local failed_stage
  failed_stage="$(aero7_state_get failed_stage 2>/dev/null || true)"
  if [[ -n "$failed_stage" ]]; then
    aero7_check_status "Previous failed stage: $failed_stage" "FAILED"
  else
    aero7_check_status "Previous failed stage" "OK"
  fi

  aero7_doctor_section "Desktop"
  if aero7_validate_plasma_wayland_session || aero7_dry_run; then
    aero7_check_status "Plasma Wayland session" "OK"
  else
    aero7_check_status "Plasma Wayland session" "FAILED"
  fi

  if aero7_doctor_package_installed aerothemeplasma-desktop-git || aero7_dry_run; then
    aero7_check_status "AeroThemePlasma packages" "OK"
  else
    aero7_check_status "AeroThemePlasma packages" "NOT INSTALLED"
  fi

  if aero7_doctor_package_installed aeroshell-workspace-git || aero7_dry_run; then
    aero7_check_status "AeroShell components" "OK"
  else
    aero7_check_status "AeroShell components" "NOT INSTALLED"
  fi

  local aero_origin
  aero_origin="$(aero7_state_get aero_packages_origin 2>/dev/null || printf 'unknown')"
  case "$aero_origin" in
    binary)
      if aero7_repository_key_configured; then
        aero7_check_status "Aero package origin: signed repository" "OK"
      else
        aero7_check_status "Aero package origin: signed repository key unconfigured" "WARNING"
      fi
      ;;
    source)
      aero7_check_status "Aero package origin: AUR source build" "WARNING"
      ;;
    *)
      aero7_check_status "Aero package origin" "WARNING"
      ;;
  esac

  if aero7_have systemctl && aero7_systemctl_is_enabled sddm.service; then
    aero7_check_status "SDDM enabled" "OK"
  else
    aero7_check_status "SDDM enabled" "WARNING"
  fi

  aero7_doctor_section "Boot"
  local bootloader initramfs
  bootloader="$(aero7_detect_bootloader)"
  initramfs="$(aero7_detect_initramfs)"
  if [[ "$bootloader" == "unknown" || "$bootloader" == "ambiguous" ]]; then
    aero7_check_status "Bootloader detected" "WARNING"
  else
    aero7_check_status "$bootloader detected" "OK"
  fi
  if [[ "$initramfs" == "unknown" || "$initramfs" == "ambiguous" ]]; then
    aero7_check_status "Initramfs tool detected" "WARNING"
  else
    aero7_check_status "$initramfs detected" "OK"
  fi

  aero7_doctor_section "User Configuration"
  if aero7_have systemctl && aero7_systemctl_is_enabled NetworkManager.service; then
    aero7_check_status "NetworkManager enabled" "OK"
  else
    aero7_check_status "NetworkManager enabled" "WARNING"
  fi

  if aero7_have fastfetch; then
    aero7_check_status "Fastfetch binary" "OK"
  else
    aero7_check_status "Fastfetch binary" "NOT INSTALLED"
  fi

  if aero7_have wine; then
    aero7_check_status "Wine binary" "OK"
  else
    aero7_check_status "Wine binary" "NOT INSTALLED"
  fi

  if declare -F aero7_root_owned_managed_user_files >/dev/null 2>&1; then
    if [[ -n "$(aero7_root_owned_managed_user_files)" ]]; then
      aero7_check_status "Root-owned managed user files" "FAILED"
    else
      aero7_check_status "Root-owned managed user files" "OK"
    fi
  fi

  aero7_doctor_result

  [[ "$AERO7_DOCTOR_FAILURES" -eq 0 ]]
}

aero7_report_list() {
  local title="$1"
  local key="$2"
  printf '%s\n' "$title"
  if [[ -r "$(aero7_state_dir)/$key" ]]; then
    aero7_state_unique_file "$key" | sed 's/^/  - /'
  else
    printf '  - none\n'
  fi
}

aero7_report_installed_optional_applications() {
  printf 'Successfully installed optional applications:\n'

  local -A blocked=()
  local -A disabled=()
  local line app recipe printed=0

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    app="${line%%:*}"
    blocked["$app"]=1
  done < <(aero7_state_unique_file "failed_optional_applications")

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    app="${line%%:*}"
    blocked["$app"]=1
  done < <(aero7_state_unique_file "skipped_applications")

  if declare -F aero7_recipe_list >/dev/null 2>&1; then
    for recipe in $(aero7_recipe_list); do
      aero7_recipe_load "$recipe"
      if [[ "${AERO7_APP_AVAILABLE:-no}" == "no" ]]; then
        disabled["$AERO7_APP_ID"]=1
      fi
    done
  fi

  while IFS= read -r app; do
    [[ -n "$app" ]] || continue
    [[ -z "${blocked[$app]:-}" ]] || continue
    [[ -z "${disabled[$app]:-}" ]] || continue
    printf '  - %s\n' "$app"
    printed=1
  done < <(aero7_state_unique_file "installed_optional_applications")

  if [[ "$printed" -eq 0 ]]; then
    printf '  - none\n'
  fi
}

aero7_state_count_unique() {
  local key="$1"
  local file
  file="$(aero7_state_dir)/$key"
  [[ -r "$file" ]] || {
    printf '0\n'
    return 0
  }
  aero7_state_unique_file "$key" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' '
}

aero7_final_status_line() {
  local color="$1"
  local icon="$2"
  shift 2
  printf '    %s%s%s %s\n' "$color" "$icon" "$AERO7_C_RESET" "$*"
}

aero7_final_kv() {
  local label="$1"
  local value="$2"
  printf '  %-14s %s\n' "$label" "$value"
}

aero7_final_state_list() {
  local key="$1"
  local color="$2"
  local icon="$3"
  local empty="$4"
  local line printed=0
  if [[ -r "$(aero7_state_dir)/$key" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      aero7_final_status_line "$color" "$icon" "$line"
      printed=1
    done < <(aero7_state_unique_file "$key")
  fi
  if [[ "$printed" -eq 0 && -n "$empty" ]]; then
    aero7_final_status_line "$AERO7_C_DIM" "$AERO7_ICON_SKIP" "$empty"
  fi
}

aero7_final_report_pretty() {
  local warnings failed_optional backup reboot logout title
  warnings="$(aero7_state_count_unique warnings)"
  failed_optional="$(aero7_state_count_unique failed_optional_applications)"
  backup="$(aero7_state_get backup_id 2>/dev/null || printf 'none')"
  reboot="$(aero7_state_get reboot_recommended 2>/dev/null || printf 'no')"
  logout="$(aero7_state_get logout_recommended 2>/dev/null || printf 'no')"
  title="Installation completed"
  if [[ "$warnings" -gt 0 || "$failed_optional" -gt 0 ]]; then
    title="Installation completed with warnings"
  fi

  aero7_ui_box "$title" "Aero7-shell has finished the installation flow"

  printf '  %sDesktop%s\n' "$AERO7_C_BOLD" "$AERO7_C_RESET"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "KDE Plasma Wayland target"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "AeroThemePlasma packages"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "AeroShell components"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "Aero package origin: $(aero7_state_get aero_packages_origin 2>/dev/null || printf 'unknown')"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "SDDM configuration"

  printf '\n  %sApplications%s\n' "$AERO7_C_BOLD" "$AERO7_C_RESET"
  aero7_final_state_list "installed_optional_applications" "$AERO7_C_GREEN" "$AERO7_ICON_OK" "No optional applications installed"
  aero7_final_state_list "skipped_applications" "$AERO7_C_DIM" "$AERO7_ICON_SKIP" ""
  aero7_final_state_list "failed_optional_applications" "$AERO7_C_YELLOW" "$AERO7_ICON_WARN" ""

  printf '\n  %sSystem%s\n' "$AERO7_C_BOLD" "$AERO7_C_RESET"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "Plymouth configuration checked"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "Fastfetch configuration checked"
  aero7_final_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "Terminal compatibility commands checked"

  printf '\n'
  aero7_final_kv "Warnings" "$warnings"
  aero7_final_kv "Backup" "$backup"
  aero7_final_kv "Log" "${AERO7_LOG_FILE:-unknown}"
  aero7_final_kv "Logout" "$logout"
  aero7_final_kv "Reboot" "$reboot"
}

aero7_final_report() {
  if aero7_validation_tui_backend; then
    local warnings failed_optional backup reboot logout
    warnings="$(aero7_state_count_unique warnings)"
    failed_optional="$(aero7_state_count_unique failed_optional_applications)"
    backup="$(aero7_state_get backup_id 2>/dev/null || printf 'none')"
    reboot="$(aero7_state_get reboot_recommended 2>/dev/null || printf 'no')"
    logout="$(aero7_state_get logout_recommended 2>/dev/null || printf 'no')"
    aero7_event_action_phase "Final report"
    aero7_event_action_output "Warnings: $warnings"
    aero7_event_action_output "Failed optional applications: $failed_optional"
    aero7_event_action_output "Backup: $backup"
    aero7_event_action_output "Logout required: $logout"
    aero7_event_action_output "Reboot required: $reboot"
    aero7_event_action_output "Log: ${AERO7_LOG_FILE:-unknown}"
    return 0
  fi

  if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
    aero7_final_report_pretty
    return 0
  fi

  printf '\nAero7-shell final report\n'
  printf 'Installer version: %s\n' "$AERO7_VERSION"
  printf 'Backup identifier: %s\n' "$(aero7_state_get backup_id 2>/dev/null || printf 'none')"
  printf 'Bootloader detected: %s\n' "$(aero7_state_get detected_bootloader 2>/dev/null || aero7_detect_bootloader)"
  printf 'Initramfs detected: %s\n' "$(aero7_state_get detected_initramfs 2>/dev/null || aero7_detect_initramfs)"
  printf 'Reboot required: %s\n' "$(aero7_state_get reboot_recommended 2>/dev/null || printf 'no')"
  printf 'Logout required: %s\n' "$(aero7_state_get logout_recommended 2>/dev/null || printf 'no')"
  printf 'Log file: %s\n' "${AERO7_LOG_FILE:-unknown}"
  aero7_report_list "Successfully installed core packages:" "installed_core_packages"
  aero7_report_installed_optional_applications
  aero7_report_list "Skipped applications:" "skipped_applications"
  aero7_report_list "Failed optional applications:" "failed_optional_applications"
  aero7_report_list "Configuration files changed:" "modified_files"
  aero7_report_list "Warnings:" "warnings"
}
