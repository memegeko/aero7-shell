#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
  printf 'test-ui-events: %s\n' "$*" >&2
  exit 1
}

tmp="$(mktemp -d)"
cleanup() {
  rm -rf -- "$tmp"
}
trap cleanup EXIT

export AERO7_PROJECT_ROOT="$repo"
export AERO7_TUI_BACKEND=1
export AERO7_CURRENT_STAGE=60-aeroshell
export AERO7_VERSION=0.1.0-test
export TERM=dumb

source "$repo/lib/common.sh"
source "$repo/lib/ui-events.sh"
source "$repo/lib/ui.sh"

events="$tmp/events.jsonl"
{
  aero7_event_session_start 15
  aero7_stage_banner 60-aeroshell 7 15
  aero7_progress_item 4 8 aeroshell-libplasma-git
  aero7_warning_line 'password=secret-token should be frontend-sanitized'
  aero7_event_action_complete 0 12
  aero7_event_stage_complete 60-aeroshell complete 'Installing Aero desktop'
  aero7_event_session_complete 1 false
} >"$events"

[[ -s "$events" ]] || fail "event stream is empty"
if grep -q $'\033' "$events"; then
  fail "event stream contains ANSI escapes"
fi

python - "$events" <<'PY' || exit 1
import json
import sys

path = sys.argv[1]
events = []
with open(path, encoding="utf-8") as handle:
    for line in handle:
        event = json.loads(line)
        assert isinstance(event.get("type"), str), event
        events.append(event)

types = [event["type"] for event in events]
required = {
    "session_start",
    "stage_start",
    "stage_progress",
    "item",
    "warning",
    "action_complete",
    "stage_complete",
    "session_complete",
}
missing = sorted(required - set(types))
assert not missing, missing
assert events[1]["id"] == "60-aeroshell"
assert events[2]["current"] == 4
assert events[2]["total"] == 8
PY

weight_total="$(awk -F= 'NF && $1 !~ /^#/ { total += $2 } END { print total + 0 }' "$repo/config/stage-weights.conf")"
[[ "$weight_total" -eq 100 ]] || fail "stage weights do not sum to 100: $weight_total"

printf 'test-ui-events: ok\n'
