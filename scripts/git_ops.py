#!/usr/bin/env python3
"""Git helpers for the MythSurvivor automation scaffold.

All mutating operations are dry-run unless --execute is passed.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def run_git(args: list[str], *, execute: bool) -> dict[str, Any]:
    command = ["git", *args]
    if not execute:
        return {"dry_run": True, "command": command}

    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return {
        "dry_run": False,
        "command": command,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    return value[:48] or "task"


def branch_name(task_id: str, title: str, prefix: str = "codex/") -> str:
    return f"{prefix}{task_id.lower()}-{slugify(title)}"


def create_branch(name: str, *, execute: bool) -> dict[str, Any]:
    if name == "main" or name.startswith("main/"):
        raise ValueError("Refusing to create or switch protected main branch through automation.")
    return run_git(["switch", "-c", name], execute=execute)


def stage(paths: list[str], *, execute: bool) -> dict[str, Any]:
    if not paths:
        raise ValueError("No paths provided to stage.")
    return run_git(["add", "--", *paths], execute=execute)


def commit(message: str, *, execute: bool) -> dict[str, Any]:
    if not message.strip():
        raise ValueError("Commit message must not be empty.")
    return run_git(["commit", "-m", message], execute=execute)


def status(*, execute: bool) -> dict[str, Any]:
    return run_git(["status", "--short"], execute=execute)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Git helpers for MythSurvivor automation.")
    parser.add_argument("--execute", action="store_true", help="Actually run mutating git commands.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    branch = subparsers.add_parser("branch-name", help="Render a safe branch name.")
    branch.add_argument("--task-id", required=True)
    branch.add_argument("--title", required=True)
    branch.add_argument("--prefix", default="codex/")

    create = subparsers.add_parser("create-branch", help="Create a task branch.")
    create.add_argument("--name", required=True)

    stage_cmd = subparsers.add_parser("stage", help="Stage paths.")
    stage_cmd.add_argument("paths", nargs="+")

    commit_cmd = subparsers.add_parser("commit", help="Create a commit.")
    commit_cmd.add_argument("--message", required=True)

    subparsers.add_parser("status", help="Show short git status.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "branch-name":
        result: Any = {"branch": branch_name(args.task_id, args.title, args.prefix)}
    elif args.command == "create-branch":
        result = create_branch(args.name, execute=args.execute)
    elif args.command == "stage":
        result = stage(args.paths, execute=args.execute)
    elif args.command == "commit":
        result = commit(args.message, execute=args.execute)
    elif args.command == "status":
        result = status(execute=True)
    else:
        raise ValueError(f"Unsupported command: {args.command}")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
