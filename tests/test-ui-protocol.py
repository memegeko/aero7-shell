#!/usr/bin/env python3
"""Protocol-level tests for the Aero7 curses frontend."""

from __future__ import annotations

import argparse
import importlib.util
import os
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
os.environ["AERO7_PROJECT_ROOT"] = str(REPO)

spec = importlib.util.spec_from_file_location("aero7_setup", REPO / "ui" / "aero7_setup.py")
assert spec and spec.loader
aero7_setup = importlib.util.module_from_spec(spec)
sys.modules["aero7_setup"] = aero7_setup
spec.loader.exec_module(aero7_setup)


def fail(message: str) -> None:
    raise SystemExit(f"test-ui-protocol: {message}")


if aero7_setup.parse_event("not json") is not None:
    fail("malformed JSON was accepted")

event = aero7_setup.parse_event('{"type":"stage_start","id":"60-aeroshell"}')
if event is None or event["type"] != "stage_start":
    fail("valid event was rejected")

sanitized = aero7_setup.sanitize("\x1b[31mpassword=hunter2\x1b[0m\r next")
if "\x1b" in sanitized or "hunter2" in sanitized:
    fail(f"sanitize leaked escape or secret: {sanitized!r}")

if sum(aero7_setup.WEIGHTS.values()) != 100:
    fail("frontend weights do not sum to 100")

args = argparse.Namespace(backend=None, backend_arg=[], demo=None)
frontend = aero7_setup.Aero7Frontend(args)
frontend.handle_event({"type": "session_start", "version": "0.1.0-test", "stages": 15})
frontend.handle_event({"type": "stage_start", "id": "60-aeroshell", "index": 7, "total": 15, "title": "Installing Aero desktop"})
frontend.handle_event({"type": "stage_progress", "id": "60-aeroshell", "current": 4, "total": 8})
if frontend.state.overall_percent() <= 0:
    fail("stage progress did not affect overall progress")

frontend.handle_event({"type": "warning", "message": "demo warning"})
if frontend.state.warnings != ["demo warning"]:
    fail("warning event was not recorded")

frontend.handle_event({"type": "session_complete", "warnings": 1, "reboot_required": False})
if frontend.state.status != "complete" or frontend.state.overall_percent() != 100:
    fail("session completion did not finish progress")

print("test-ui-protocol: ok")
