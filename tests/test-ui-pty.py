#!/usr/bin/env python3
"""PTY smoke test for the full-screen Aero7 curses frontend."""

from __future__ import annotations

import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(f"test-ui-pty: {message}")


master_fd, slave_fd = pty.openpty()
fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))

env = os.environ.copy()
env.pop("CI", None)
env.update(
    {
        "TERM": "xterm-256color",
        "AERO7_PROJECT_ROOT": str(REPO),
        "AERO7_TEST_FAST": "1",
    }
)

proc = subprocess.Popen(
    [str(REPO / "install.sh"), "--ui-demo", "success"],
    stdin=slave_fd,
    stdout=slave_fd,
    stderr=slave_fd,
    cwd=REPO,
    env=env,
)
os.close(slave_fd)

captured = bytearray()
deadline = time.monotonic() + 15
answered_completion = False
try:
    while time.monotonic() < deadline:
        ready, _, _ = select.select([master_fd], [], [], 0.2)
        if ready:
            try:
                chunk = os.read(master_fd, 8192)
            except OSError:
                break
            if not chunk:
                break
            captured.extend(chunk)
            if not answered_completion and b"Reboot now?" in captured:
                os.write(master_fd, b"n")
                answered_completion = True
        if proc.poll() is not None:
            ready, _, _ = select.select([master_fd], [], [], 0)
            if ready:
                try:
                    captured.extend(os.read(master_fd, 8192))
                except OSError:
                    pass
            break
finally:
    os.close(master_fd)

if proc.poll() is None:
    proc.terminate()
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
    fail("ui demo timed out")

if proc.returncode != 0:
    sys.stderr.buffer.write(bytes(captured[-4000:]))
    fail(f"ui demo exited {proc.returncode}")
if not answered_completion:
    sys.stderr.buffer.write(bytes(captured[-4000:]))
    fail("completion reboot dialog was not observed")

output = bytes(captured)
if b"\x1b[?1049h" not in output and b"\x1b[?47h" not in output:
    fail("alternate screen enter sequence was not observed")
if b"Aero7-shell setup interface closed." not in output:
    fail("frontend did not close cleanly")

print("test-ui-pty: ok")
