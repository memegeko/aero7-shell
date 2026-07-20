#!/usr/bin/env bash

if [[ -n "${AERO7_APPLICATIONS_LOADED:-}" ]]; then
  return 0
fi
AERO7_APPLICATIONS_LOADED=1

aero7_recipe_clear() {
  unset AERO7_APP_ID AERO7_APP_NAME AERO7_APP_AUTHOR AERO7_APP_SOURCE_URL
  unset AERO7_APP_REF AERO7_APP_LICENSE AERO7_APP_DEPENDENCIES
  unset AERO7_APP_OPTIONAL_DEPENDENCIES AERO7_APP_SUPPORTED_SESSION
  unset AERO7_APP_BUILD_SYSTEM AERO7_APP_SOURCE_SUBDIR AERO7_APP_INSTALL_KIND
  unset AERO7_APP_AUR_PACKAGE AERO7_APP_VALIDATE_COMMAND AERO7_APP_FATAL
  unset AERO7_APP_EXPERIMENTAL AERO7_APP_AVAILABLE AERO7_APP_REASON
  unset AERO7_APP_BRANCH AERO7_APP_BUILD_COMMAND AERO7_APP_INSTALL_COMMAND
  unset AERO7_APP_UNINSTALL_METADATA AERO7_APP_PLASMA6_COMPAT AERO7_APP_WAYLAND_COMPAT
  unset AERO7_APP_REPLACES_PACKAGES
}

aero7_recipe_list() {
  find "$AERO7_RECIPE_DIR" -maxdepth 1 -type f -name '*.sh' | sort
}

aero7_recipe_load() {
  local recipe="$1"
  aero7_recipe_clear
  # shellcheck source=/dev/null
  source "$recipe"
  local required=(
    AERO7_APP_ID
    AERO7_APP_NAME
    AERO7_APP_AUTHOR
    AERO7_APP_SUPPORTED_SESSION
    AERO7_APP_BUILD_SYSTEM
    AERO7_APP_INSTALL_KIND
    AERO7_APP_FATAL
    AERO7_APP_EXPERIMENTAL
    AERO7_APP_AVAILABLE
    AERO7_APP_SOURCE_URL
    AERO7_APP_BRANCH
    AERO7_APP_DEPENDENCIES
    AERO7_APP_BUILD_COMMAND
    AERO7_APP_INSTALL_COMMAND
    AERO7_APP_VALIDATE_COMMAND
    AERO7_APP_UNINSTALL_METADATA
    AERO7_APP_PLASMA6_COMPAT
    AERO7_APP_WAYLAND_COMPAT
    AERO7_APP_LICENSE
  )
  local var
  for var in "${required[@]}"; do
    [[ -n "${!var:-}" ]] || aero7_die "Recipe $recipe is missing $var."
  done
}

aero7_app_validate_current_recipe() {
  if [[ -z "${AERO7_APP_VALIDATE_COMMAND:-}" ]]; then
    return 0
  fi
  if aero7_dry_run; then
    aero7_detail "Would validate $AERO7_APP_NAME"
    return 0
  fi
  aero7_run bash -lc "$AERO7_APP_VALIDATE_COMMAND"
}

aero7_app_install_current_recipe() {
  if [[ "$AERO7_APP_SUPPORTED_SESSION" != "wayland" && "$AERO7_APP_SUPPORTED_SESSION" != "any" ]]; then
    aero7_skip "$AERO7_APP_NAME skipped: not marked Wayland-compatible"
    aero7_state_append "skipped_applications" "$AERO7_APP_ID: not marked Wayland-compatible"
    return 0
  fi

  if [[ "$AERO7_APP_AVAILABLE" != "yes" ]]; then
    aero7_skip "$AERO7_APP_NAME skipped: ${AERO7_APP_REASON:-recipe unavailable}"
    aero7_state_append "skipped_applications" "$AERO7_APP_ID: ${AERO7_APP_REASON:-recipe unavailable}"
    return 0
  fi

  if [[ "$AERO7_APP_EXPERIMENTAL" == "yes" ]]; then
    aero7_warn "$AERO7_APP_NAME is experimental."
  fi

  aero7_action "Installing $AERO7_APP_NAME"
  case "$AERO7_APP_INSTALL_KIND" in
    aur)
      [[ -n "${AERO7_APP_AUR_PACKAGE:-}" ]] || aero7_die "$AERO7_APP_NAME recipe lacks AUR package."
      aero7_yay_install_packages "$AERO7_APP_AUR_PACKAGE" || return 1
      ;;
    git-cmake)
      [[ -n "${AERO7_APP_SOURCE_URL:-}" ]] || aero7_die "$AERO7_APP_NAME recipe lacks source URL."
      local source_dir="$AERO7_CACHE_DIR/sources/$AERO7_APP_ID"
      local build_dir="$AERO7_CACHE_DIR/build/$AERO7_APP_ID"
      local cmake_source="$source_dir/${AERO7_APP_SOURCE_SUBDIR:-.}"
      if aero7_dry_run; then
        aero7_detail "Would clone $AERO7_APP_SOURCE_URL and build with CMake"
        return 0
      fi
      aero7_detail "Preparing source"
      aero7_user_run install -d -m 0755 "$AERO7_CACHE_DIR/sources" "$AERO7_CACHE_DIR/build" || return 1
      if [[ -d "$source_dir/.git" ]]; then
        aero7_detail "Updating source"
        aero7_user_run git -C "$source_dir" pull --ff-only || return 1
      else
        aero7_detail "Cloning source"
        aero7_user_run git clone "$AERO7_APP_SOURCE_URL" "$source_dir" || return 1
      fi
      if [[ -n "${AERO7_APP_REF:-}" && "$AERO7_APP_REF" != "default" ]]; then
        aero7_detail "Checking out requested revision"
        aero7_user_run git -C "$source_dir" checkout "$AERO7_APP_REF" || return 1
      fi
      [[ -f "$cmake_source/CMakeLists.txt" ]] || aero7_die "$AERO7_APP_NAME does not have CMakeLists.txt at $cmake_source."
      aero7_detail "Configuring"
      aero7_user_run cmake -S "$cmake_source" -B "$build_dir" -G Ninja || return 1
      aero7_detail "Building"
      aero7_user_run cmake --build "$build_dir" || return 1
      aero7_detail "Installing"
      aero7_sudo_run cmake --install "$build_dir" || return 1
      ;;
    unavailable)
      aero7_skip "Skipping unavailable recipe $AERO7_APP_NAME"
      ;;
    *)
      aero7_die "Unsupported install kind for $AERO7_APP_NAME: $AERO7_APP_INSTALL_KIND"
      ;;
  esac

  if aero7_app_validate_current_recipe; then
    aero7_state_append "installed_optional_applications" "$AERO7_APP_ID"
    aero7_ok "$AERO7_APP_NAME installed"
    return 0
  fi

  {
    if [[ "$AERO7_APP_FATAL" == "yes" ]]; then
      aero7_die "$AERO7_APP_NAME did not validate."
    fi
    aero7_warn "$AERO7_APP_NAME did not validate."
    aero7_state_append "failed_optional_applications" "$AERO7_APP_ID: validation failed"
  }
}

aero7_apps_install_defaults() {
  local recipe
  local failures=()
  for recipe in $(aero7_recipe_list); do
    aero7_recipe_load "$recipe"
    case "$AERO7_APP_ID" in
      winxplorer)
        aero7_prompt_optional_app AERO7_INSTALL_WINXPLORER "WinXplorer" || {
          aero7_info "User skipped WinXplorer."
          aero7_state_append "skipped_applications" "winxplorer: user declined or noninteractive default"
          continue
        }
        ;;
      sevulet)
        aero7_prompt_optional_app AERO7_INSTALL_SEVULET "Sevulet" || {
          aero7_info "User skipped Sevulet."
          aero7_state_append "skipped_applications" "sevulet: user declined or noninteractive default"
          continue
        }
        ;;
    esac

    if ! aero7_app_install_current_recipe; then
      if [[ "${AERO7_APP_FATAL:-no}" == "yes" ]]; then
        return 1
      fi
      failures+=("$AERO7_APP_NAME")
      aero7_state_append "failed_optional_applications" "$AERO7_APP_ID: install failed"
      aero7_warning_line "$AERO7_APP_NAME could not be installed"
      aero7_detail "The application was skipped and desktop installation will continue."
      if [[ -n "${AERO7_LOG_FILE:-}" ]]; then
        aero7_detail "Full details: $AERO7_LOG_FILE"
      fi
    fi
  done

  if [[ "${#failures[@]}" -gt 0 ]]; then
    aero7_warn "Nonfatal application failures: ${failures[*]}"
  fi
}

aero7_apps_may_need_aur() {
  local recipe
  for recipe in $(aero7_recipe_list); do
    aero7_recipe_load "$recipe"
    [[ "$AERO7_APP_SUPPORTED_SESSION" == "wayland" || "$AERO7_APP_SUPPORTED_SESSION" == "any" ]] || continue
    [[ "$AERO7_APP_AVAILABLE" == "yes" ]] || continue
    [[ "$AERO7_APP_INSTALL_KIND" == "aur" ]] || continue
    case "$AERO7_APP_ID" in
      winxplorer)
        [[ "${AERO7_INSTALL_WINXPLORER:-ask}" != "no" ]] || continue
        ;;
      sevulet)
        [[ "${AERO7_INSTALL_SEVULET:-ask}" != "no" ]] || continue
        ;;
    esac
    return 0
  done
  return 1
}

aero7_app_status_line() {
  local color="$1"
  local icon="$2"
  shift 2
  if declare -F aero7_doctor_line >/dev/null 2>&1; then
    aero7_doctor_line "$color" "$icon" "$@"
  else
    printf '    %s%s%s %s\n' "$color" "$icon" "${AERO7_C_RESET:-}" "$*"
  fi
}

aero7_apps_status() {
  local recipe available=0 unavailable=0 total=0
  if [[ -n "${AERO7_UI_LOADED:-}" ]] && ! aero7_ui_quiet; then
    aero7_ui_box "Aero7-shell Applications" ""
  fi

  for recipe in $(aero7_recipe_list); do
    aero7_recipe_load "$recipe"
    total=$((total + 1))
    if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
      if [[ "$AERO7_APP_AVAILABLE" == "yes" ]]; then
        available=$((available + 1))
        aero7_app_status_line "$AERO7_C_GREEN" "$AERO7_ICON_OK" "$AERO7_APP_NAME ($AERO7_APP_ID)"
      else
        unavailable=$((unavailable + 1))
        aero7_app_status_line "$AERO7_C_DIM" "$AERO7_ICON_SKIP" "$AERO7_APP_NAME: ${AERO7_APP_REASON:-recipe unavailable}"
      fi
    else
      printf '%-18s %-10s %s\n' "$AERO7_APP_ID" "$AERO7_APP_AVAILABLE" "${AERO7_APP_REASON:-$AERO7_APP_INSTALL_KIND}"
    fi
  done

  if [[ -n "${AERO7_UI_LOADED:-}" ]]; then
    printf '\n  %sResult%s        %d available, %d unavailable, %d total\n' \
      "$AERO7_C_CYAN" "$AERO7_C_RESET" "$available" "$unavailable" "$total"
  fi
}
