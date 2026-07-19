#!/usr/bin/env python3
"""Run the real Aero7 curses frontend in demo mode."""

from __future__ import annotations

import os
import subprocess
import sys


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "success"
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    return subprocess.call([sys.executable, os.path.join(root, "ui", "aero7_setup.py"), "--demo", mode])


if __name__ == "__main__":
    raise SystemExit(main())
