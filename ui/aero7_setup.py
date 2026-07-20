#!/usr/bin/env python3
"""Curses frontend for Aero7-shell setup."""

from __future__ import annotations

import argparse
import curses
import json
import os
import queue
import re
import shlex
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


STAGE_TITLES = {
    "00-preflight": "Preparing system",
    "10-backup": "Creating backups",
    "20-system-update": "Updating system",
    "30-base-dependencies": "Installing base packages",
    "40-plasma-wayland": "Installing Plasma Wayland",
    "50-yay": "Preparing AUR helper",
    "55-binary-repository": "Configuring binary repository",
    "60-aeroshell": "Installing Aero desktop",
    "70-aero-applications": "Installing applications",
    "80-plasma-layout": "Applying Plasma layout",
    "90-sddm": "Configuring SDDM",
    "100-plymouth": "Configuring Plymouth",
    "110-fastfetch": "Configuring Fastfetch",
    "120-wine": "Configuring Wine",
    "130-terminal-compat": "Installing terminal commands",
    "140-validation": "Validating installation",
}


DEFAULT_WEIGHTS = {
    "00-preflight": 3,
    "10-backup": 5,
    "20-system-update": 7,
    "30-base-dependencies": 10,
    "40-plasma-wayland": 10,
    "50-yay": 3,
    "55-binary-repository": 4,
    "60-aeroshell": 16,
    "70-aero-applications": 14,
    "80-plasma-layout": 5,
    "90-sddm": 5,
    "100-plymouth": 8,
    "110-fastfetch": 2,
    "120-wine": 2,
    "130-terminal-compat": 2,
    "140-validation": 4,
}


def load_stage_weights() -> dict[str, int]:
    root = Path(os.environ.get("AERO7_PROJECT_ROOT", Path(__file__).resolve().parents[1]))
    path = root / "config" / "stage-weights.conf"
    weights = DEFAULT_WEIGHTS.copy()
    try:
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            weights[key.strip()] = int(value.strip())
    except (OSError, ValueError):
        return DEFAULT_WEIGHTS.copy()
    if sum(weights.get(stage_id, 0) for stage_id in STAGE_TITLES) != 100:
        return DEFAULT_WEIGHTS.copy()
    return weights


WEIGHTS = load_stage_weights()


ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
SECRET_RE = re.compile(r"(?i)(password|token|secret|key)=\S+")


def sanitize(text: Any, width: int = 200) -> str:
    value = str(text)
    value = ANSI_RE.sub("", value)
    value = value.replace("\r", " ")
    value = CONTROL_RE.sub("", value)
    value = SECRET_RE.sub(r"\1=<redacted>", value)
    value = re.sub(r"\s+", " ", value).strip()
    if len(value) > width:
        return value[: max(0, width - 1)] + "…"
    return value


def parse_event(line: str) -> dict[str, Any] | None:
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        return None
    if not isinstance(event, dict):
        return None
    if not isinstance(event.get("type"), str):
        return None
    return event


def format_duration(seconds: float) -> str:
    total = max(0, int(seconds))
    return f"{total // 60:02d}:{total % 60:02d}"


@dataclass
class InstallerState:
    version: str = "0.1.0"
    log_path: str = ""
    stages_total: int = 16
    current_stage_id: str = ""
    current_stage_title: str = "Waiting for backend"
    current_stage_index: int = 0
    stage_units_current: int = 0
    stage_units_total: int = 1
    action_title: str = "Starting installer"
    action_phase: str = "Initializing"
    latest_output: str = ""
    latest_output_time: float = field(default_factory=time.monotonic)
    started_at: float = field(default_factory=time.monotonic)
    action_started_at: float = field(default_factory=time.monotonic)
    completed_weight: int = 0
    max_progress: float = 0.0
    status: str = "running"
    failure_message: str = ""
    warnings: list[str] = field(default_factory=list)
    live_log: list[str] = field(default_factory=list)
    timeline: dict[str, str] = field(default_factory=dict)
    stage_order: list[str] = field(default_factory=lambda: list(STAGE_TITLES))
    package_current: int = 0
    package_total: int = 0
    package_name: str = ""
    cancel_dialog: bool = False
    completion_dialog: bool = False
    reboot_required: bool = False
    reboot_prompt_enabled: bool = False
    reboot_in_progress: bool = False
    reboot_error: str = ""
    exit_requested: bool = False
    view: str = "main"
    follow_log: bool = True
    log_scroll: int = 0
    backend_exit_code: int | None = None

    def stage_progress_percent(self) -> float:
        total = max(1, self.stage_units_total)
        return min(1.0, max(0.0, self.stage_units_current / total))

    def visible_stage_progress_percent(self) -> float:
        progress = self.stage_progress_percent()
        if self.package_total > 0 and self.package_current > 0:
            package_progress = self.package_current / max(1, self.package_total)
            progress = max(progress, package_progress)
        return min(1.0, max(0.0, progress))

    def overall_percent(self) -> int:
        weight = WEIGHTS.get(self.current_stage_id, 0)
        current = self.completed_weight + weight * self.stage_progress_percent()
        if self.status == "complete":
            current = 100
        if self.status == "failed":
            current = min(current, 99)
        self.max_progress = max(self.max_progress, min(100.0, current))
        return int(self.max_progress)


class Aero7Frontend:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.state = InstallerState()
        self.events: queue.Queue[dict[str, Any]] = queue.Queue()
        self.stop_event = threading.Event()
        self.backend: subprocess.Popen[str] | None = None
        self.debug_log = os.environ.get("AERO7_TUI_DEBUG_LOG", "/tmp/aero7-tui-debug.log")
        self.spinner = "◐◓◑◒" if os.environ.get("NO_COLOR") != "1" else "|/-\\"
        self.color = os.environ.get("NO_COLOR") != "1"

    def log_debug(self, message: str) -> None:
        try:
            with open(self.debug_log, "a", encoding="utf-8") as handle:
                handle.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
        except OSError:
            pass

    def enqueue(self, event: dict[str, Any]) -> None:
        self.events.put(event)

    def start_backend(self) -> None:
        if self.args.demo:
            threading.Thread(target=self.demo_events, args=(self.args.demo,), daemon=True).start()
            return
        if not self.args.backend:
            self.enqueue({"type": "session_failed", "message": "No backend command configured"})
            return
        env = os.environ.copy()
        env["AERO7_TUI_BACKEND"] = "1"
        env["PYTHONUNBUFFERED"] = "1"
        command = [self.args.backend, *self.args.backend_arg]
        self.backend = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env,
        )
        threading.Thread(target=self.read_backend_stdout, daemon=True).start()
        threading.Thread(target=self.read_backend_stderr, daemon=True).start()
        threading.Thread(target=self.wait_backend, daemon=True).start()

    def read_backend_stdout(self) -> None:
        assert self.backend and self.backend.stdout
        for line in self.backend.stdout:
            stripped = line.strip()
            if not stripped:
                continue
            event = parse_event(stripped)
            if event is None:
                self.log_debug(f"malformed event: {sanitize(stripped, 500)}")
                self.enqueue({"type": "action_output", "text": sanitize(stripped)})
            else:
                self.enqueue(event)

    def read_backend_stderr(self) -> None:
        assert self.backend and self.backend.stderr
        for line in self.backend.stderr:
            self.enqueue({"type": "action_output", "text": sanitize(line)})

    def wait_backend(self) -> None:
        assert self.backend
        code = self.backend.wait()
        self.enqueue({"type": "backend_exit", "exit_code": code})

    def demo_events(self, mode: str) -> None:
        speed = 0.1 if os.environ.get("AERO7_TEST_FAST") == "1" else 1.0
        total = len(STAGE_TITLES)
        self.enqueue({"type": "session_start", "version": "0.1.0-alpha", "stages": total, "log": "/tmp/aero7-demo.log"})
        if mode == "small-terminal":
            self.enqueue({"type": "action_start", "title": "Terminal is too small for comfortable setup"})
            time.sleep(2 * speed)
            self.enqueue({"type": "session_failed", "message": "terminal is smaller than 80x24"})
            return
        start_index = 1
        if mode == "resumed":
            for idx, stage_id in enumerate(list(STAGE_TITLES)[:6], start=1):
                self.enqueue({"type": "stage_start", "id": stage_id, "index": idx, "total": total, "title": STAGE_TITLES[stage_id]})
                self.enqueue({"type": "stage_complete", "id": stage_id, "status": "complete", "title": STAGE_TITLES[stage_id]})
            start_index = 7
        if mode in {"aur-build", "resumed"}:
            self.enqueue({"type": "stage_start", "id": "60-aeroshell", "index": 8, "total": total, "title": "Installing Aero desktop"})
            packages = [
                "aeroshell-libplasma-git",
                "aeroshell-workspace-git",
                "aeroshell-kwin-components-git",
                "aerothemeplasma-icons-git",
                "aerothemeplasma-sounds-git",
                "aeroshell-smod-git",
                "uac-polkit-agent-git",
                "aerothemeplasma-desktop-git",
            ]
            for index, package in enumerate(packages, start=1):
                self.enqueue({"type": "stage_progress", "id": "60-aeroshell", "current": index - 1, "total": len(packages)})
                self.enqueue({"type": "item", "status": "active", "name": package})
                self.enqueue({"type": "action_start", "title": f"Building {package}", "package_current": index, "package_total": len(packages), "package": package})
                for tick in range(3 if os.environ.get("AERO7_TEST_FAST") == "1" else 4):
                    phase = ["resolving dependencies", "downloading sources", "compiling", "packaging"][tick % 4]
                    self.enqueue({"type": "action_phase", "name": phase})
                    self.enqueue({"type": "action_heartbeat", "seconds_since_output": tick, "text": f"[{index}/{len(packages)}] {phase} {package}"})
                    time.sleep(speed)
                self.enqueue({"type": "stage_progress", "id": "60-aeroshell", "current": index, "total": len(packages)})
                self.enqueue({"type": "item", "status": "complete", "name": package})
            self.enqueue({"type": "stage_complete", "id": "60-aeroshell", "status": "complete", "title": "Installing Aero desktop"})
            if mode == "aur-build":
                self.enqueue({"type": "session_complete", "warnings": 0, "reboot_required": False})
            return
        for idx, stage_id in enumerate(list(STAGE_TITLES)[start_index - 1 :], start=start_index):
            self.enqueue({"type": "stage_start", "id": stage_id, "index": idx, "total": total, "title": STAGE_TITLES[stage_id]})
            self.enqueue({"type": "action_start", "title": STAGE_TITLES[stage_id]})
            time.sleep(speed)
            if mode == "failure" and idx == 5:
                self.enqueue({"type": "session_failed", "stage": stage_id, "message": "Demo failure"})
                return
            if mode == "warning" and idx == 8:
                self.enqueue({"type": "warning", "message": "Demo warning"})
            self.enqueue({"type": "stage_complete", "id": stage_id, "status": "complete", "title": STAGE_TITLES[stage_id]})
        if mode == "cancellation":
            self.enqueue({"type": "cancel_requested"})
        else:
            reboot_required = mode == "success" or os.environ.get("AERO7_TUI_DEMO_REBOOT") == "1"
            self.enqueue(
                {
                    "type": "session_complete",
                    "warnings": 1 if mode == "warning" else 0,
                    "reboot_required": reboot_required,
                    "reboot_prompt_enabled": reboot_required,
                }
            )

    def handle_event(self, event: dict[str, Any]) -> None:
        typ = event.get("type")
        now = time.monotonic()
        if typ == "session_start":
            self.state.version = str(event.get("version", self.state.version))
            self.state.stages_total = int(event.get("stages", self.state.stages_total))
            self.state.log_path = str(event.get("log", ""))
        elif typ == "stage_start":
            stage_id = str(event.get("id", ""))
            self.state.current_stage_id = stage_id
            self.state.current_stage_title = str(event.get("title", STAGE_TITLES.get(stage_id, stage_id)))
            self.state.current_stage_index = int(event.get("index", self.state.current_stage_index or 1))
            self.state.stages_total = int(event.get("total", self.state.stages_total))
            self.state.stage_units_current = 0
            self.state.stage_units_total = 1
            self.state.package_current = 0
            self.state.package_total = 0
            self.state.package_name = ""
            self.state.timeline[stage_id] = "active"
            self.state.action_started_at = now
        elif typ == "stage_progress":
            self.state.stage_units_current = int(event.get("current", 0))
            self.state.stage_units_total = max(1, int(event.get("total", 1)))
        elif typ == "stage_complete":
            stage_id = str(event.get("id", self.state.current_stage_id))
            status = str(event.get("status", "complete"))
            if self.state.timeline.get(stage_id) != "complete":
                self.state.completed_weight = min(100, self.state.completed_weight + WEIGHTS.get(stage_id, 0))
            self.state.timeline[stage_id] = status
            self.state.stage_units_current = self.state.stage_units_total
        elif typ == "action_start":
            self.state.action_title = sanitize(event.get("title", "Working"))
            self.state.action_phase = "working"
            self.state.action_started_at = now
            self.state.package_current = int(event.get("package_current", self.state.package_current))
            self.state.package_total = int(event.get("package_total", self.state.package_total))
            self.state.package_name = sanitize(event.get("package", self.state.package_name))
        elif typ == "action_phase":
            self.state.action_phase = sanitize(event.get("name", "working"))
        elif typ in {"action_output", "action_heartbeat"}:
            text = sanitize(event.get("text", ""))
            if text:
                self.state.latest_output = text
                self.state.live_log.append(text)
                self.state.live_log = self.state.live_log[-500:]
                self.state.latest_output_time = now
        elif typ == "item":
            name = sanitize(event.get("name", ""))
            status = str(event.get("status", ""))
            if status == "active":
                self.state.package_name = name
            self.state.live_log.append(f"{status}: {name}")
        elif typ == "action_complete":
            code = int(event.get("exit_code", 0))
            if code == 0:
                self.state.action_phase = "completed"
            else:
                self.state.action_phase = f"failed with exit {code}"
        elif typ == "warning":
            message = sanitize(event.get("message", "Warning"))
            self.state.warnings.append(message)
            self.state.live_log.append(f"warning: {message}")
        elif typ == "session_complete":
            self.state.status = "complete"
            self.state.completed_weight = 100
            self.state.action_title = "Installation flow completed"
            self.state.action_phase = "complete"
            self.state.reboot_required = bool(event.get("reboot_required", False))
            self.state.reboot_prompt_enabled = bool(event.get("reboot_prompt_enabled", self.state.reboot_required))
            self.state.completion_dialog = True
        elif typ == "session_failed":
            self.state.status = "failed"
            self.state.failure_message = sanitize(event.get("message", "Installation failed"))
            self.stop_event.set()
        elif typ == "cancel_requested":
            self.state.cancel_dialog = True
        elif typ == "backend_exit":
            self.state.backend_exit_code = int(event.get("exit_code", 1))
            if self.state.status == "running" and self.state.backend_exit_code != 0:
                self.state.status = "failed"
                self.state.failure_message = f"Backend exited with {self.state.backend_exit_code}"
                self.stop_event.set()

    def drain_events(self) -> None:
        while True:
            try:
                self.handle_event(self.events.get_nowait())
            except queue.Empty:
                return

    def init_colors(self) -> None:
        if not curses.has_colors() or not self.color:
            return
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLUE)
        curses.init_pair(2, curses.COLOR_CYAN, -1)
        curses.init_pair(3, curses.COLOR_GREEN, -1)
        curses.init_pair(4, curses.COLOR_YELLOW, -1)
        curses.init_pair(5, curses.COLOR_RED, -1)
        curses.init_pair(6, curses.COLOR_BLACK, curses.COLOR_CYAN)

    def pair(self, index: int) -> int:
        if not self.color or not curses.has_colors():
            return 0
        return curses.color_pair(index)

    def run(self, stdscr: Any) -> int:
        self.stdscr = stdscr
        curses.curs_set(0)
        stdscr.nodelay(True)
        stdscr.keypad(True)
        self.init_colors()
        signal.signal(signal.SIGINT, lambda _sig, _frame: self.enqueue({"type": "cancel_requested"}))
        self.start_backend()
        final_seen_at: float | None = None
        while True:
            self.drain_events()
            self.draw()
            key = self.get_key()
            if key is not None:
                self.handle_key(key)
            if self.state.exit_requested:
                break
            if self.state.status in {"complete", "failed", "cancelled"}:
                if final_seen_at is None:
                    final_seen_at = time.monotonic()
                if self.state.status != "complete" and time.monotonic() - final_seen_at > float(os.environ.get("AERO7_TUI_EXIT_DELAY", "1.5")):
                    break
            time.sleep(0.08)
        if self.state.status == "cancelled":
            return 130
        return self.state.backend_exit_code or (1 if self.state.status == "failed" else 0)

    def get_key(self) -> int | None:
        try:
            key = self.stdscr.getch()
        except curses.error:
            return None
        if key == -1:
            return None
        return key

    def handle_key(self, key: int) -> None:
        if self.state.status == "complete":
            self.handle_completion_key(key)
            return
        if self.state.cancel_dialog:
            if key in (ord("c"), ord("C"), ord("q"), ord("Q"), 10, 13):
                self.cancel_backend()
                self.state.status = "cancelled"
                self.stop_event.set()
            elif key in (27, ord("n"), ord("N")):
                self.state.cancel_dialog = False
            return
        if key in (3, ord("q"), ord("Q")):
            self.state.cancel_dialog = True
        elif key in (ord("l"), ord("L")):
            self.state.view = "log" if self.state.view != "log" else "main"
            self.state.follow_log = True
        elif key in (ord("d"), ord("D")):
            self.state.view = "details" if self.state.view != "details" else "main"
        elif key in (ord("w"), ord("W")):
            self.state.view = "warnings" if self.state.view != "warnings" else "main"
        elif key in (ord("h"), ord("H")):
            self.state.view = "help" if self.state.view != "help" else "main"
        elif key in (27,):
            self.state.view = "main"
        elif self.state.view == "log":
            if key == curses.KEY_UP:
                self.state.log_scroll = max(0, self.state.log_scroll - 1)
                self.state.follow_log = False
            elif key == curses.KEY_DOWN:
                self.state.log_scroll += 1
            elif key == curses.KEY_NPAGE:
                self.state.log_scroll += 10
            elif key == curses.KEY_PPAGE:
                self.state.log_scroll = max(0, self.state.log_scroll - 10)
                self.state.follow_log = False
            elif key == curses.KEY_END:
                self.state.follow_log = True

    def handle_completion_key(self, key: int) -> None:
        if self.state.reboot_in_progress:
            return
        if self.state.reboot_required and self.state.reboot_prompt_enabled:
            if key in (ord("y"), ord("Y")):
                self.request_reboot()
            elif key in (ord("n"), ord("N"), ord("q"), ord("Q"), 10, 13, 27):
                self.state.exit_requested = True
            return
        if key in (ord("q"), ord("Q"), 10, 13, 27):
            self.state.exit_requested = True

    def request_reboot(self) -> None:
        self.state.reboot_in_progress = True
        self.state.reboot_error = ""
        self.state.action_title = "Rebooting now"
        self.state.action_phase = "sending reboot command"

        if self.args.demo:
            self.state.live_log.append("reboot: demo mode, no command executed")
            self.state.exit_requested = True
            return

        command_text = os.environ.get("AERO7_TUI_REBOOT_COMMAND", "sudo -n systemctl reboot")
        try:
            command = shlex.split(command_text)
            if not command:
                raise ValueError("empty reboot command")
            result = subprocess.run(
                command,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=15,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired, ValueError) as exc:
            self.state.reboot_in_progress = False
            self.state.reboot_error = sanitize(str(exc), 120)
            self.state.action_phase = "reboot command failed"
            return

        output = sanitize((result.stderr or result.stdout or "").strip(), 160)
        if result.returncode == 0:
            self.state.live_log.append("reboot: command accepted")
            self.state.exit_requested = True
            return

        self.state.reboot_in_progress = False
        self.state.reboot_error = output or f"command exited with {result.returncode}"
        self.state.action_phase = "reboot command failed"

    def cancel_backend(self) -> None:
        if self.backend and self.backend.poll() is None:
            self.backend.send_signal(signal.SIGINT)
            try:
                self.backend.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.backend.terminate()

    def draw(self) -> None:
        stdscr = self.stdscr
        rows, cols = stdscr.getmaxyx()
        stdscr.erase()
        if rows < 20 or cols < 70:
            self.add(0, 0, "Aero7-shell Setup - terminal too small", self.pair(5) | curses.A_BOLD)
            self.add(2, 0, "Resize to at least 80x24, or run ./install.sh --plain.")
            stdscr.refresh()
            return
        self.draw_frame(rows, cols)
        if self.state.view == "log":
            self.draw_log(rows, cols)
        elif self.state.view == "details":
            self.draw_details(rows, cols)
        elif self.state.view == "warnings":
            self.draw_warnings(rows, cols)
        elif self.state.view == "help":
            self.draw_help(rows, cols)
        else:
            self.draw_main(rows, cols)
        if self.state.completion_dialog:
            self.draw_completion_dialog(rows, cols)
        elif self.state.cancel_dialog:
            self.draw_cancel_dialog(rows, cols)
        stdscr.refresh()

    def add(self, y: int, x: int, text: str, attr: int = 0) -> None:
        rows, cols = self.stdscr.getmaxyx()
        if y < 0 or y >= rows or x >= cols:
            return
        safe = sanitize(text, max(1, cols - x - 1))
        try:
            self.stdscr.addstr(y, x, safe[: max(0, cols - x - 1)], attr)
        except curses.error:
            pass

    def add_raw(self, y: int, x: int, text: str, attr: int = 0) -> None:
        rows, cols = self.stdscr.getmaxyx()
        if y < 0 or y >= rows or x >= cols:
            return
        try:
            self.stdscr.addstr(y, x, text[: max(0, cols - x - 1)], attr)
        except curses.error:
            pass

    def color_ready(self) -> bool:
        return self.color and curses.has_colors()

    def draw_frame(self, rows: int, cols: int) -> None:
        title_attr = self.pair(1) | curses.A_BOLD
        self.stdscr.attron(title_attr)
        self.add_raw(0, 0, " " * (cols - 1), title_attr)
        self.add(0, 2, "Aero7-shell Setup", title_attr)
        version = self.state.version
        self.add(0, max(2, cols - len(version) - 4), version, title_attr)
        self.stdscr.attroff(title_attr)
        self.add_raw(1, 0, "─" * (cols - 1), self.pair(2))
        self.add_raw(rows - 3, 0, "─" * (cols - 1), self.pair(2))
        if self.state.status == "complete":
            if self.state.reboot_required and self.state.reboot_prompt_enabled:
                footer = "  Y Reboot now    N Reboot later  "
            else:
                footer = "  Enter Close    Q Close  "
        else:
            footer = "  D Details    L Live log    W Warnings    H Help    Q Cancel safely  "
        self.add_raw(rows - 2, 0, footer.ljust(cols - 1), self.pair(1))

    def draw_progress_bar(self, y: int, x: int, width: int, percent: float, active: bool = False) -> None:
        width = max(10, width)
        fill = int(width * max(0.0, min(1.0, percent)))
        self.add_raw(y, x, "┌" + "─" * width + "┐", self.pair(2))
        self.add_raw(y + 1, x, "│", self.pair(2))
        if self.color_ready():
            attr = self.pair(6) | (curses.A_BOLD if active else 0)
            self.add_raw(y + 1, x + 1, " " * width, 0)
            if fill > 0:
                self.add_raw(y + 1, x + 1, " " * fill, attr)
        else:
            bar = "#" * fill + "." * (width - fill)
            self.add_raw(y + 1, x + 1, bar)
        self.add_raw(y + 1, x + width + 1, "│", self.pair(2))
        self.add_raw(y + 2, x, "└" + "─" * width + "┘", self.pair(2))

    def draw_flat_progress_bar(self, y: int, x: int, width: int, percent: float, active: bool = False) -> None:
        width = max(10, width)
        inner = max(8, width - 2)
        fill = int(inner * max(0.0, min(1.0, percent)))
        self.add_raw(y, x, "[", self.pair(2))
        if self.color_ready():
            attr = self.pair(6) | (curses.A_BOLD if active else 0)
            self.add_raw(y, x + 1, " " * inner, 0)
            if fill > 0:
                self.add_raw(y, x + 1, " " * fill, attr)
        else:
            bar = "#" * fill + "." * (inner - fill)
            self.add_raw(y, x + 1, bar)
        self.add_raw(y, x + inner + 1, "]", self.pair(2))

    def draw_activity_bar(self, y: int, x: int, width: int) -> None:
        width = max(10, width)
        tick = int(time.monotonic() * 8) % width
        chars = [" "] * width
        for offset in range(8):
            chars[(tick + offset) % width] = "▓"
        self.add_raw(y, x, "[" + "".join(chars) + "]", self.pair(2))

    def draw_main(self, rows: int, cols: int) -> None:
        left = 4
        width = cols - 10
        y = 3
        overall = self.state.overall_percent()
        if rows < 30:
            self.add(y, left, "Installing Aero7-shell", curses.A_BOLD)
            self.add(y + 1, left, "Windows 7-inspired Plasma desktop for Arch Linux")
            self.add(y + 3, left, f"Overall progress {overall:3d}%")
            self.draw_flat_progress_bar(y + 4, left, width - 4, overall / 100, active=True)
            stage_count = f"{self.state.current_stage_index or 0} of {self.state.stages_total}"
            self.add(y + 6, left, self.state.current_stage_title, curses.A_BOLD)
            self.add(y + 6, left + width - len(stage_count) - 2, stage_count)
            self.draw_flat_progress_bar(y + 7, left, width - 4, self.state.visible_stage_progress_percent())
            self.add(y + 9, left, "Current operation", curses.A_BOLD)
            self.add(y + 10, left, self.state.action_title)
            spinner = self.spinner[int(time.monotonic() * 5) % len(self.spinner)]
            self.add(y + 11, left, f"{spinner} {self.state.action_phase}", self.pair(2) | curses.A_BOLD)
            if self.state.package_total:
                self.add(y + 12, left, f"Package {self.state.package_current} of {self.state.package_total}: {self.state.package_name}")
            elapsed = format_duration(time.monotonic() - self.state.started_at)
            op_elapsed = format_duration(time.monotonic() - self.state.action_started_at)
            last_age = int(time.monotonic() - self.state.latest_output_time)
            self.add(y + 13, left, f"Elapsed {elapsed}   Operation {op_elapsed}   Last activity {last_age}s")
            latest = self.state.latest_output or f"Still working, no new output for {last_age} seconds"
            if last_age > 120:
                latest = "This operation is taking longer than usual, but is still running."
            self.add(y + 14, left, "Latest: " + latest)
            self.draw_timeline(y + 16, left, rows - 4)
            return

        self.add(y, left, "Installing Aero7-shell", curses.A_BOLD)
        self.add(y + 1, left, "Windows 7-inspired Plasma desktop for Arch Linux")
        self.add(y + 3, left, "Overall progress")
        self.add(y + 3, left + width - 6, f"{overall:3d}%")
        self.draw_progress_bar(y + 4, left, width - 4, overall / 100, active=True)
        y += 8
        stage_label = f"{self.state.current_stage_title}"
        stage_count = f"{self.state.current_stage_index or 0} of {self.state.stages_total}"
        self.add(y, left, stage_label, curses.A_BOLD)
        self.add(y, left + width - len(stage_count) - 2, stage_count)
        self.draw_progress_bar(y + 1, left, width - 4, self.state.visible_stage_progress_percent())
        y += 5
        self.add(y, left, "Current operation", curses.A_BOLD)
        self.add(y + 1, left, self.state.action_title)
        spinner = self.spinner[int(time.monotonic() * 5) % len(self.spinner)]
        self.add(y + 3, left, f"{spinner} {self.state.action_phase}", self.pair(2) | curses.A_BOLD)
        if self.state.package_total:
            self.add(y + 4, left, f"Package progress: {self.state.package_current} of {self.state.package_total}  {self.state.package_name}")
        self.draw_activity_bar(y + 5, left, min(width - 4, 54))
        elapsed = format_duration(time.monotonic() - self.state.started_at)
        op_elapsed = format_duration(time.monotonic() - self.state.action_started_at)
        last_age = int(time.monotonic() - self.state.latest_output_time)
        self.add(y + 7, left, f"Elapsed  {elapsed}                 Current operation  {op_elapsed}")
        self.add(y + 8, left, f"Last activity  {last_age} seconds ago  Remaining  calculating...")
        latest = self.state.latest_output or f"Still working — no new output for {last_age} seconds"
        if last_age > 120:
            latest = "This operation is taking longer than usual, but is still running."
        self.add(y + 10, left, "Latest: " + latest)
        timeline_y = y + 12
        self.draw_timeline(timeline_y, left, rows - 5)

    def draw_timeline(self, y: int, x: int, bottom: int) -> None:
        visible = max(3, bottom - y)
        order = self.state.stage_order
        current_index = max(0, order.index(self.state.current_stage_id) if self.state.current_stage_id in order else 0)
        start = max(0, min(current_index - 4, len(order) - visible))
        for offset, stage_id in enumerate(order[start : start + visible]):
            status = self.state.timeline.get(stage_id, "pending")
            icon = {"complete": "✓", "skipped": "○", "active": "→", "failed": "✗"}.get(status, "○")
            attr = self.pair(3) if status == "complete" else self.pair(2) if status == "active" else self.pair(4) if status == "skipped" else self.pair(5) if status == "failed" else 0
            self.add(y + offset, x, f"{icon} {STAGE_TITLES.get(stage_id, stage_id)}", attr)

    def draw_log(self, rows: int, cols: int) -> None:
        self.add(3, 4, "Live log", curses.A_BOLD)
        lines = self.state.live_log[-(rows - 8) :]
        if not self.state.follow_log:
            start = min(max(0, self.state.log_scroll), max(0, len(self.state.live_log) - (rows - 8)))
            lines = self.state.live_log[start : start + rows - 8]
        for idx, line in enumerate(lines):
            self.add(5 + idx, 4, sanitize(line, cols - 8))

    def draw_details(self, rows: int, cols: int) -> None:
        details = [
            ("Installer version", self.state.version),
            ("Stage index", f"{self.state.current_stage_index} of {self.state.stages_total}"),
            ("Stage ID", self.state.current_stage_id),
            ("Current command", self.state.action_title),
            ("Current package", self.state.package_name),
            ("Warnings", str(len(self.state.warnings))),
            ("Log path", self.state.log_path),
            ("Elapsed", format_duration(time.monotonic() - self.state.started_at)),
        ]
        self.add(3, 4, "Details", curses.A_BOLD)
        for idx, (key, value) in enumerate(details):
            if 5 + idx >= rows - 4:
                break
            self.add(5 + idx, 4, f"{key:<20} {value}", self.pair(2) if idx % 2 else 0)

    def draw_warnings(self, rows: int, cols: int) -> None:
        self.add(3, 4, "Warnings", curses.A_BOLD)
        warnings = self.state.warnings or ["No warnings recorded."]
        for idx, line in enumerate(warnings[-(rows - 8) :]):
            self.add(5 + idx, 4, sanitize(line, cols - 8), self.pair(4))

    def draw_help(self, rows: int, cols: int) -> None:
        lines = [
            "D toggles installer details.",
            "L toggles the live log.",
            "W shows warnings collected during this run.",
            "Esc returns to the main progress screen.",
            "Q or Ctrl+C opens the safe cancellation dialog.",
        ]
        self.add(3, 4, "Help", curses.A_BOLD)
        for idx, line in enumerate(lines):
            if 5 + idx >= rows - 4:
                break
            self.add(5 + idx, 4, line, self.pair(2))

    def draw_cancel_dialog(self, rows: int, cols: int) -> None:
        width = min(68, cols - 8)
        height = 9
        y = max(2, rows // 2 - height // 2)
        x = max(2, cols // 2 - width // 2)
        self.add(y, x, "┌" + "─" * (width - 2) + "┐", self.pair(5) | curses.A_BOLD)
        self.add(y + 1, x, "│ Cancel installation? " + " " * (width - 24) + "│", self.pair(5) | curses.A_BOLD)
        for line_no in range(2, height - 1):
            self.add(y + line_no, x, "│" + " " * (width - 2) + "│", self.pair(5))
        self.add(y + 3, x + 3, f"Aero7-shell is currently {self.state.action_phase}.")
        self.add(y + 5, x + 3, "Cancelling now will stop after the current safe operation.")
        self.add(y + 7, x + 8, "[ Continue installation: Esc ]    [ Cancel safely: Enter ]", self.pair(6) | curses.A_BOLD)
        self.add(y + height - 1, x, "└" + "─" * (width - 2) + "┘", self.pair(5) | curses.A_BOLD)

    def draw_completion_dialog(self, rows: int, cols: int) -> None:
        width = min(72, cols - 8)
        height = 11 if self.state.reboot_error else 10
        y = max(2, rows // 2 - height // 2)
        x = max(2, cols // 2 - width // 2)
        border_attr = self.pair(2) | curses.A_BOLD
        self.add(y, x, "┌" + "─" * (width - 2) + "┐", border_attr)
        self.add(y + 1, x, "│ Installation complete " + " " * (width - 25) + "│", border_attr)
        for line_no in range(2, height - 1):
            self.add(y + line_no, x, "│" + " " * (width - 2) + "│", self.pair(2))

        self.add(y + 3, x + 3, "Aero7-shell has finished the installation flow.")
        if self.state.reboot_required and self.state.reboot_prompt_enabled:
            self.add(y + 5, x + 3, "A reboot is recommended so all desktop changes load cleanly.")
            if self.state.reboot_in_progress:
                self.add(y + 7, x + 3, "Sending reboot command...", self.pair(2) | curses.A_BOLD)
            else:
                self.add(y + 7, x + 3, "Reboot now?", curses.A_BOLD)
                button_y = y + 8
                if self.state.reboot_error:
                    self.add(y + 8, x + 3, "Could not reboot automatically: " + self.state.reboot_error, self.pair(5))
                    button_y = y + 9
                self.add(button_y, x + 7, "[ Y Yes, reboot now ]    [ N No, reboot later ]", self.pair(6) | curses.A_BOLD)
        else:
            if self.state.reboot_required:
                self.add(y + 5, x + 3, "A reboot is recommended, but this run will not start it.")
                self.add(y + 6, x + 3, "Close this screen and reboot manually when ready.")
            else:
                self.add(y + 5, x + 3, "No reboot prompt is needed for this run.")
            self.add(y + 8, x + 12, "[ Enter Close ]", self.pair(6) | curses.A_BOLD)

        self.add(y + height - 1, x, "└" + "─" * (width - 2) + "┘", border_attr)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend")
    parser.add_argument("--backend-arg", action="append", default=[])
    parser.add_argument("--demo", choices=["success", "warning", "failure", "aur-build", "cancellation", "resumed", "small-terminal"])
    args = parser.parse_args()
    app = Aero7Frontend(args)
    try:
        return curses.wrapper(app.run)
    except Exception as exc:  # terminal cleanup is handled by curses.wrapper
        app.log_debug(f"frontend exception: {exc!r}")
        print(f"Aero7-shell TUI failed: {exc}", file=sys.stderr)
        return 1
    finally:
        print("Aero7-shell setup interface closed.")


if __name__ == "__main__":
    raise SystemExit(main())
