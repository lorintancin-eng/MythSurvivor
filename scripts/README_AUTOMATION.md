# MythSurvivor Automation Scaffold

This directory contains the first automation skeleton for a multi-agent development team. It is intentionally non-invasive: it does not call OpenAI, does not modify gameplay code, does not create real branches by default, and does not create GitHub pull requests by default.

## Files

- `.agent/agents.yaml`: Agent registry, responsibilities, prompt paths, and expected outputs.
- `.agent/workflow.yaml`: End-to-end flow from task intake to draft PR and human merge gate.
- `.agent/permissions.yaml`: Path ownership and protected path policy for each agent.
- `.agent/tasks.example.json`: Example task packages for future runs.
- `.agent/prompts/*.md`: System prompt templates for each specialized agent.
- `scripts/orchestrator.py`: Dry-run planner for task-to-agent workflow execution.
- `scripts/agent_runner.py`: Stub runner for one agent. This is the future OpenAI API integration point.
- `scripts/github_tasks.py`: Dry-run GitHub PR helper with an optional `gh pr create` execution path.
- `scripts/git_ops.py`: Dry-run git helper for branch, stage, commit, and status operations.
- `scripts/godot_test_runner.py`: Placeholder for Godot headless smoke checks and future test harnesses.

## Current Usage

Preview the example tasks:

```powershell
python scripts/orchestrator.py --task-file .agent/tasks.example.json
```

Preview and run local stub agents without any model call:

```powershell
python scripts/orchestrator.py --task-file .agent/tasks.example.json --execute-stubs --json
```

Preview the Godot smoke-check command:

```powershell
python scripts/godot_test_runner.py --dry-run
```

Preview a future Git branch name:

```powershell
python scripts/git_ops.py branch-name --task-id MS-123 --title "Add original skill"
```

## Future OpenAI Integration

Replace `build_stub_response()` in `scripts/agent_runner.py` with a real model call:

1. Read the agent prompt from `.agent/prompts/{agent}.md`.
2. Load the task package, permission policy, and relevant repository context.
3. Send the prompt and task to the OpenAI API with a strict structured JSON output schema.
4. Save the model response under `.agent/runs/{task_id}/{agent}.json`.
5. Let the orchestrator validate the response before allowing file writes.

Recommended environment variables:

```powershell
$env:OPENAI_API_KEY="..."
$env:OPENAI_MODEL="gpt-5.2"
```

## Future GitHub Integration

After authentication and branch policy are configured:

1. Use `scripts/git_ops.py create-branch --execute` to create task branches.
2. Let implementation agents edit only approved paths.
3. Run `scripts/godot_test_runner.py --execute`.
4. Stage approved files with `scripts/git_ops.py stage --execute`.
5. Commit with `scripts/git_ops.py commit --execute`.
6. Create a draft PR with `scripts/github_tasks.py create-pr --execute`.
7. Keep merge to `main` manual.

Recommended environment variables:

```powershell
$env:GH_TOKEN="..."
$env:GODOT_BIN="C:\Path\To\Godot_v4.x.exe"
```
