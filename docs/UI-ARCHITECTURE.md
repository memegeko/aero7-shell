# Aero7-shell UI Architecture

Aero7-shell keeps installation logic in Bash and renders the normal interactive installer through a Python standard-library `curses` frontend.

## Entrypoints

- `./install.sh` automatically selects the full-screen TUI when stdin/stdout are TTYs, `TERM` is usable, the terminal is at least 80x24, and the run is not `--plain`, `--debug`, or CI.
- `./install.sh --tui` or `AERO7_TUI=1 ./install.sh` forces TUI startup. If it cannot start, the installer prints the exact reason and exits.
- `./install.sh --plain` keeps the old line-oriented renderer for redirected logs, CI, unsupported terminals, and debugging.
- `./install.sh --ui-diagnostics` prints the selection inputs and chosen mode.
- `./install.sh --ui-demo MODE` runs frontend demos without performing installation work.

## Bootstrap

Minimal Arch systems may not have Python yet. Before launching curses, `install.sh` may show a tiny loader, validate sudo, install the `python` package, and then relaunch into the frontend. Once Python is available, the stage flow is rendered by `ui/aero7_setup.py`.

## Backend Protocol

The backend runs as:

```bash
AERO7_TUI_BACKEND=1 ./install.sh --backend-run ...
```

In that mode, Bash UI helpers emit newline-delimited JSON events through stdout. Ordinary command output is captured into the log and forwarded as sanitized `action_output` / `action_heartbeat` events. The frontend never parses plain terminal logs to infer progress.

Important event types:

- `session_start`, `session_complete`, `session_failed`
- `stage_start`, `stage_progress`, `stage_complete`
- `action_start`, `action_phase`, `action_output`, `action_heartbeat`, `action_complete`
- `item`, `warning`

Stage weights live in `config/stage-weights.conf` and must sum to 100.

## Frontend

`ui/aero7_setup.py` owns all normal interactive drawing:

- alternate screen through curses
- fixed title bar, content area, and footer
- overall and current-stage progress
- current operation and live activity heartbeat
- Details, Live Log, Warnings, Help, and safe cancellation dialog

Installation stages should not draw terminal UI directly. They should call shared helpers such as `aero7_action`, `aero7_detail`, `aero7_progress_item`, `aero7_warn`, and `aero7_ok`.
