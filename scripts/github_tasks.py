#!/usr/bin/env python3
"""GitHub task helpers for the MythSurvivor automation scaffold.

The default behavior is dry-run. Real PR creation should be enabled only after
GitHub authentication and branch policy are configured.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def create_pull_request(
    *,
    title: str,
    body: str,
    head: str,
    base: str = "main",
    draft: bool = True,
    execute: bool = False,
) -> dict[str, Any]:
    command = [
        "gh",
        "pr",
        "create",
        "--base",
        base,
        "--head",
        head,
        "--title",
        title,
        "--body",
        body,
    ]
    if draft:
        command.append("--draft")

    if not execute:
        return {
            "dry_run": True,
            "command": command,
            "message": "PR was not created. Re-run with --execute after GitHub auth is configured.",
        }

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GitHub helpers for MythSurvivor automation.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create = subparsers.add_parser("create-pr", help="Create or preview a draft pull request.")
    create.add_argument("--title", required=True)
    create.add_argument("--body", required=True)
    create.add_argument("--head", required=True)
    create.add_argument("--base", default="main")
    create.add_argument("--ready", action="store_true", help="Create a ready PR instead of a draft.")
    create.add_argument("--execute", action="store_true", help="Actually run gh pr create.")

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "create-pr":
        result = create_pull_request(
            title=args.title,
            body=args.body,
            head=args.head,
            base=args.base,
            draft=not args.ready,
            execute=args.execute,
        )
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    raise ValueError(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
