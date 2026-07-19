#!/usr/bin/env bash

if [[ -n "${AERO7_UI_EVENTS_LOADED:-}" ]]; then
  return 0
fi
AERO7_UI_EVENTS_LOADED=1

aero7_tui_backend() {
  [[ "${AERO7_TUI_BACKEND:-0}" == "1" ]]
}

aero7_event_emit() {
  aero7_tui_backend || return 0
  local event_type="$1"
  shift || true
  python - "$event_type" "$@" <<'PY'
import json
import sys

event = {"type": sys.argv[1]}
for raw in sys.argv[2:]:
    if "=" not in raw:
        continue
    key, value = raw.split("=", 1)
    if value == "true":
        event[key] = True
    elif value == "false":
        event[key] = False
    else:
        try:
            if value and (value.isdigit() or (value[0] == "-" and value[1:].isdigit())):
                event[key] = int(value)
            else:
                event[key] = value
        except Exception:
            event[key] = value
print(json.dumps(event, ensure_ascii=False, separators=(",", ":")), flush=True)
PY
}

aero7_event_session_start() {
  aero7_event_emit session_start \
    "version=${AERO7_VERSION:-unknown}" \
    "stages=${1:-0}" \
    "log=${AERO7_LOG_FILE:-}"
}

aero7_event_session_complete() {
  aero7_event_emit session_complete \
    "warnings=${1:-0}" \
    "reboot_required=${2:-false}" \
    "log=${AERO7_LOG_FILE:-}"
}

aero7_event_session_failed() {
  aero7_event_emit session_failed \
    "stage=${AERO7_CURRENT_STAGE:-startup}" \
    "message=$*"
}

aero7_event_stage_start() {
  aero7_event_emit stage_start \
    "id=$1" \
    "index=$2" \
    "total=$3" \
    "title=$4"
}

aero7_event_stage_complete() {
  aero7_event_emit stage_complete \
    "id=$1" \
    "status=${2:-complete}" \
    "title=${3:-$1}"
}

aero7_event_stage_progress() {
  aero7_event_emit stage_progress \
    "id=${AERO7_CURRENT_STAGE:-startup}" \
    "current=$1" \
    "total=$2" \
    "title=${3:-}"
}

aero7_event_action_start() {
  aero7_event_emit action_start \
    "title=$*" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}

aero7_event_action_phase() {
  aero7_event_emit action_phase \
    "name=$*" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}

aero7_event_action_output() {
  aero7_event_emit action_output \
    "text=$*" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}

aero7_event_action_heartbeat() {
  aero7_event_emit action_heartbeat \
    "seconds_since_output=${1:-0}" \
    "text=${2:-}" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}

aero7_event_action_complete() {
  aero7_event_emit action_complete \
    "exit_code=${1:-0}" \
    "duration=${2:-0}" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}

aero7_event_item() {
  local status="$1"
  shift
  aero7_event_emit item \
    "status=$status" \
    "name=$*" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}

aero7_event_warning() {
  aero7_event_emit warning \
    "message=$*" \
    "stage=${AERO7_CURRENT_STAGE:-startup}"
}
