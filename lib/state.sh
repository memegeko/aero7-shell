#!/usr/bin/env bash

if [[ -n "${AERO7_STATE_LOADED:-}" ]]; then
  return 0
fi
AERO7_STATE_LOADED=1

aero7_state_dir() {
  if [[ -n "${AERO7_STATE_ROOT_OVERRIDE:-}" ]]; then
    printf '%s\n' "$AERO7_STATE_ROOT_OVERRIDE"
  elif aero7_dry_run; then
    printf '%s\n' "$AERO7_USER_STATE_DIR/dry-run/state"
  else
    printf '%s\n' "$AERO7_SYSTEM_STATE_DIR/state"
  fi
}

aero7_state_init() {
  aero7_init_paths
  local dir
  dir="$(aero7_state_dir)"
  if aero7_dry_run || [[ "$dir" == "$AERO7_USER_STATE_DIR"* ]] || [[ -n "${AERO7_STATE_ROOT_OVERRIDE:-}" ]]; then
    mkdir -p -- "$dir/completed" "$dir/failed" "$dir/options"
  else
    aero7_sudo_run install -d -m 0755 "$dir/completed" "$dir/failed" "$dir/options"
  fi
}

aero7_state_write_file() {
  local path="$1"
  local value="$2"
  local dir
  dir="$(dirname -- "$path")"
  if aero7_dry_run || [[ "$path" == "$AERO7_USER_STATE_DIR"* ]] || [[ -n "${AERO7_STATE_ROOT_OVERRIDE:-}" ]]; then
    mkdir -p -- "$dir"
    printf '%s\n' "$value" >"$path"
  else
    printf '%s\n' "$value" | aero7_write_root_text "$path" 0644
  fi
}

aero7_state_set() {
  local key="$1"
  local value="$2"
  aero7_valid_key "$key" || aero7_die "Invalid state key: $key"
  aero7_state_init
  aero7_state_write_file "$(aero7_state_dir)/$key" "$value"
}

aero7_state_get() {
  local key="$1"
  aero7_valid_key "$key" || return 1
  local file
  file="$(aero7_state_dir)/$key"
  [[ -r "$file" ]] || return 1
  cat "$file"
}

aero7_state_clear() {
  local key="$1"
  aero7_valid_key "$key" || aero7_die "Invalid state key: $key"
  local file
  file="$(aero7_state_dir)/$key"
  if aero7_dry_run || [[ "$file" == "$AERO7_USER_STATE_DIR"* ]] || [[ -n "${AERO7_STATE_ROOT_OVERRIDE:-}" ]]; then
    [[ ! -e "$file" ]] || rm -- "$file"
  else
    aero7_sudo rm -f -- "$file"
  fi
}

aero7_state_mark_stage_complete() {
  local stage="$1"
  aero7_valid_key "$stage" || aero7_die "Invalid stage id: $stage"
  aero7_state_init
  aero7_state_write_file "$(aero7_state_dir)/completed/$stage" "$(date -Is)"
  aero7_state_set "failed_stage" ""
}

aero7_state_mark_stage_failed() {
  local stage="$1"
  aero7_valid_key "$stage" || aero7_die "Invalid stage id: $stage"
  aero7_state_init
  aero7_state_write_file "$(aero7_state_dir)/failed/$stage" "$(date -Is)"
  aero7_state_set "failed_stage" "$stage"
}

aero7_state_stage_complete() {
  local stage="$1"
  [[ -f "$(aero7_state_dir)/completed/$stage" ]]
}

aero7_state_record_option() {
  local key="$1"
  local value="$2"
  aero7_valid_key "$key" || aero7_die "Invalid option key: $key"
  aero7_state_write_file "$(aero7_state_dir)/options/$key" "$value"
}

aero7_state_append() {
  local key="$1"
  local value="$2"
  local file dir
  aero7_valid_key "$key" || aero7_die "Invalid state key: $key"
  aero7_state_init
  file="$(aero7_state_dir)/$key"
  dir="$(dirname -- "$file")"
  if aero7_dry_run || [[ "$file" == "$AERO7_USER_STATE_DIR"* ]] || [[ -n "${AERO7_STATE_ROOT_OVERRIDE:-}" ]]; then
    mkdir -p -- "$dir"
    printf '%s\n' "$value" >>"$file"
  else
    printf '%s\n' "$value" | aero7_sudo tee -a "$file" >/dev/null
  fi
}

aero7_state_unique_file() {
  local key="$1"
  local file
  file="$(aero7_state_dir)/$key"
  [[ -r "$file" ]] || return 0
  sort -u "$file"
}

aero7_state_completed_list() {
  local dir
  dir="$(aero7_state_dir)/completed"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -type f -printf '%f\n' | sort
}
