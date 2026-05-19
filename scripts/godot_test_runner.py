#!/usr/bin/env python3
"""Godot headless test runner placeholder for MythSurvivor automation."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def build_command(
    *,
    godot_bin: str,
    project_root: Path,
    test_script: str | None = None,
    extra_args: list[str] | None = None,
) -> list[str]:
    command = [godot_bin, "--headless", "--path", str(project_root)]
    if test_script:
        command.extend(["--script", test_script])
    else:
        command.append("--quit")
    if extra_args:
        command.extend(extra_args)
    return command


def run_godot_check(
    *,
    godot_bin: str,
    project_root: Path,
    test_script: str | None,
    extra_args: list[str],
    execute: bool,
) -> dict[str, Any]:
    command = build_command(
        godot_bin=godot_bin,
        project_root=project_root,
        test_script=test_script,
        extra_args=extra_args,
    )
    if not execute:
        return {
            "dry_run": True,
            "command": command,
            "message": "Godot was not launched. Re-run with --execute when GODOT_BIN is configured.",
        }

    completed = subprocess.run(
        command,
        cwd=project_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return {
        "dry_run": False,
        "command": command,
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "passed": completed.returncode == 0,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Godot headless smoke checks for MythSurvivor.")
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--project-root", type=Path, default=ROOT)
    parser.add_argument("--test-script", help="Optional Godot script path for a future test harness.")
    parser.add_argument("--extra-arg", action="append", default=[], help="Additional argument passed to Godot.")
    parser.add_argument("--execute", action="store_true", help="Actually launch Godot.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Explicit dry-run flag for workflow readability. This is the default without --execute.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = run_godot_check(
        godot_bin=args.godot_bin,
        project_root=args.project_root.resolve(),
        test_script=args.test_script,
        extra_args=args.extra_arg,
        execute=args.execute and not args.dry_run,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result.get("dry_run"):
        return 0
    return 0 if result.get("passed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
