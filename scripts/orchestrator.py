#!/usr/bin/env python3
"""Scaffold orchestrator for the MythSurvivor multi-agent workflow.

This first version only plans and prints the workflow. It does not call the
OpenAI API, does not change git state, and does not create GitHub PRs.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
AGENT_DIR = ROOT / ".agent"
DEFAULT_TASK_FILE = AGENT_DIR / "tasks.example.json"
AGENTS_FILE = AGENT_DIR / "agents.yaml"
WORKFLOW_FILE = AGENT_DIR / "workflow.yaml"
PERMISSIONS_FILE = AGENT_DIR / "permissions.yaml"

DEFAULT_FLOW = [
    "intake",
    "pm_breakdown",
    "preflight",
    "create_branch",
    "implementation",
    "qa",
    "review",
    "commit",
    "create_pr",
    "human_merge_gate",
]


@dataclass(frozen=True)
class PlannedRun:
    task_id: str
    title: str
    branch_name: str
    agents: list[str]
    flow: list[str]


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def normalize_tasks(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("tasks"), list):
        return payload["tasks"]
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        return [payload]
    raise ValueError("Task file must contain an object, an object with tasks, or a task list.")


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    return value[:48] or "task"


def infer_agents(task: dict[str, Any]) -> list[str]:
    explicit_agents = task.get("agents")
    if isinstance(explicit_agents, list) and explicit_agents:
        return [str(agent) for agent in explicit_agents]

    text = " ".join(str(task.get(key, "")) for key in ("title", "type", "summary")).lower()
    implementation_agents: list[str] = []
    if "menu" in text or "hud" in text or "ui" in text:
        implementation_agents.append("menu_agent")
    if "feedback" in text or "vfx" in text or "audio" in text:
        implementation_agents.append("feedback_agent")
    if "balance" in text or "wave" in text or "tune" in text:
        implementation_agents.append("balance_agent")
    if "skill" in text or "weapon" in text or "upgrade" in text:
        implementation_agents.append("skill_agent")
    if not implementation_agents:
        implementation_agents.append("skill_agent")

    return ["pm_agent", *implementation_agents, "qa_agent", "reviewer_agent"]


def build_plan(task: dict[str, Any]) -> PlannedRun:
    task_id = str(task.get("id") or "MS-TASK")
    title = str(task.get("title") or task_id)
    branch_name = f"codex/{task_id.lower()}-{slugify(title)}"
    return PlannedRun(
        task_id=task_id,
        title=title,
        branch_name=branch_name,
        agents=infer_agents(task),
        flow=DEFAULT_FLOW,
    )


def existing_config_files() -> list[str]:
    return [
        str(path.relative_to(ROOT))
        for path in (AGENTS_FILE, WORKFLOW_FILE, PERMISSIONS_FILE)
        if path.exists()
    ]


def call_agent_runner(agent: str, task: dict[str, Any], dry_run: bool) -> dict[str, Any]:
    command = [
        sys.executable,
        str(ROOT / "scripts" / "agent_runner.py"),
        "--agent",
        agent,
        "--task-json",
        json.dumps(task, ensure_ascii=False),
    ]
    if dry_run:
        command.append("--dry-run")

    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return json.loads(completed.stdout)


def render_plan(plan: PlannedRun) -> str:
    lines = [
        f"Task: {plan.task_id} - {plan.title}",
        f"Branch: {plan.branch_name}",
        f"Agents: {', '.join(plan.agents)}",
        "Flow:",
    ]
    lines.extend(f"  - {step}" for step in plan.flow)
    return "\n".join(lines)


def orchestrate(tasks: Iterable[dict[str, Any]], execute_stubs: bool) -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    for task in tasks:
        plan = build_plan(task)
        print(render_plan(plan))
        print()

        agent_results: list[dict[str, Any]] = []
        if execute_stubs:
            for agent in plan.agents:
                agent_results.append(call_agent_runner(agent, task, dry_run=True))

        summaries.append(
            {
                "task_id": plan.task_id,
                "title": plan.title,
                "branch_name": plan.branch_name,
                "agents": plan.agents,
                "flow": plan.flow,
                "executed_stub_agents": bool(execute_stubs),
                "agent_results": agent_results,
            }
        )
    return summaries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Plan MythSurvivor multi-agent automation runs.")
    parser.add_argument(
        "--task-file",
        type=Path,
        default=DEFAULT_TASK_FILE,
        help="JSON task file. Defaults to .agent/tasks.example.json.",
    )
    parser.add_argument(
        "--execute-stubs",
        action="store_true",
        help="Run local stub agent_runner.py for each planned agent. Still no API calls.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable summary after the plan.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    task_file = args.task_file.resolve()
    if not task_file.exists():
        raise FileNotFoundError(f"Task file not found: {task_file}")

    payload = load_json(task_file)
    tasks = normalize_tasks(payload)

    print("MythSurvivor automation orchestrator scaffold")
    print("Mode: dry-run planning only; no OpenAI API, git writes, or GitHub PR creation.")
    print(f"Loaded configs: {', '.join(existing_config_files())}")
    print(f"Loaded tasks: {len(tasks)}")
    print()

    summaries = orchestrate(tasks, execute_stubs=args.execute_stubs)
    if args.json:
        print(json.dumps({"runs": summaries}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
