#!/usr/bin/env bash

stage_check() {
  return 0
}

stage_run() {
  local choice
  choice="$(aero7_prompt_layout_choice)"
  case "$choice" in
    apply)
      aero7_state_record_option "layout" "applied"
      aero7_apply_plasma_theme
      aero7_apply_plasma_layout
      aero7_apply_wallpaper
      ;;
    keep)
      aero7_state_record_option "layout" "kept"
      aero7_apply_plasma_theme
      ;;
    cancel)
      aero7_die "Installation cancelled before Plasma layout replacement."
      ;;
  esac
}

stage_validate() {
  return 0
}

stage_rollback() {
  return 0
}
