#!/usr/bin/env python3
"""Local stub runner for one MythSurvivor automation agent.

This file intentionally does not call any model provider. The integration
point for the OpenAI API is build_stub_response().
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
AGENT_DIR = ROOT / ".agent"
PROMPT_DIR = AGENT_DIR / "prompts"
PERMISSIONS_FILE = AGENT_DIR / "permissions.yaml"

PROMPT_FILES = {
    "pm_agent": PROMPT_DIR / "pm_agent.md",
    "skill_agent": PROMPT_DIR / "skill_agent.md",
    "menu_agent": PROMPT_DIR / "menu_agent.md",
    "feedback_agent": PROMPT_DIR / "feedback_agent.md",
    "balance_agent": PROMPT_DIR / "balance_agent.md",
    "qa_agent": PROMPT_DIR / "qa_agent.md",
    "reviewer_agent": PROMPT_DIR / "reviewer_agent.md",
}


def load_task(args: argparse.Namespace) -> dict[str, Any]:
    if args.task_json:
        task = json.loads(args.task_json)
        if not isinstance(task, dict):
            raise ValueError("--task-json must decode to a JSON object.")
        return task
    if args.task_file:
        with args.task_file.open("r", encoding="utf-8") as handle:
            task = json.load(handle)
        if isinstance(task, dict) and "tasks" in task:
            tasks = task["tasks"]
            if not tasks:
                raise ValueError("Task file contains an empty tasks list.")
            return tasks[0]
        if isinstance(task, dict):
            return task
    raise ValueError("Provide either --task-json or --task-file.")


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def build_stub_response(agent: str, task: dict[str, Any], dry_run: bool) -> dict[str, Any]:
    prompt_path = PROMPT_FILES.get(agent)
    if prompt_path is None:
        raise ValueError(f"Unknown agent: {agent}")

    prompt_text = read_text(prompt_path)
    permissions_text = read_text(PERMISSIONS_FILE)

    return {
        "agent": agent,
        "mode": "stub",
        "dry_run": dry_run,
        "task_id": task.get("id"),
        "task_title": task.get("title"),
        "prompt_path": relative(prompt_path),
        "prompt_loaded": bool(prompt_text),
        "permissions_loaded": bool(permissions_text),
        "message": "No model call was made. Replace build_stub_response with an OpenAI API call when integration is approved.",
        "expected_next_output": "structured agent report",
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one MythSurvivor automation agent in stub mode.")
    parser.add_argument("--agent", required=True, choices=sorted(PROMPT_FILES))
    parser.add_argument("--task-json", help="Task JSON object as a string.")
    parser.add_argument("--task-file", type=Path, help="Path to a task JSON file.")
    parser.add_argument("--out", type=Path, help="Optional path for writing the stub response JSON.")
    parser.add_argument("--dry-run", action="store_true", help="Keep the run explicitly marked as dry-run.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    task = load_task(args)
    response = build_stub_response(args.agent, task, dry_run=args.dry_run)
    rendered = json.dumps(response, ensure_ascii=False, indent=2)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
