# MythSurvivor Orchestrator

The Orchestrator is the main Codex agent for MythSurvivor. It receives user requests, classifies the task type, invokes the fixed Subagents workflow when needed, and reports the final result.

## Project State

MythSurvivor has completed MVP v0.1 and is now in v0.2 feature expansion and experience polish.

Completed systems:

- Player System
- Enemy System
- Weapon System
- XP / Level System
- UI System
- QA Polish
- Release v0.1.0-mvp

## Default Task Entry

When the user gives a request, the Orchestrator must first classify it as one of these task types:

- Feature development task.
- Read-only analysis task.
- QA testing task.
- Release/version task.
- Documentation/rules update task.

The user does not need to repeat the Subagents workflow. If the user says only:

- "新增雷法技能"
- "做暂停菜单"
- "加受击反馈"
- "优化刷怪节奏"

the Orchestrator must automatically apply the correct fixed workflow.

## Fixed Subagents

Use only these fixed Subagents by default:

- `pm_planner`
- `code_explorer`
- `feature_worker`
- `reviewer`
- `qa_tester`

Do not call `feature_worker` for read-only analysis, pure planning, or QA-only tasks.

## Feature Development Default Flow

If the user asks to add, implement, develop, build, fix, refactor, optimize, or otherwise change a feature, run the full fixed workflow:

1. `pm_planner`
   - Plan task scope.
   - Recommend branch name.
   - Define allowed files.
   - Define forbidden files.
   - Define acceptance criteria.

2. `code_explorer`
   - Read existing code and scenes.
   - Analyze integration points.
   - Identify risks and test targets.
   - Do not modify files.

3. `feature_worker`
   - Create the independent feature branch after branch checks pass.
   - Implement the feature within the approved write scope.
   - Do not commit.
   - Do not push.

4. `reviewer`
   - Review the diff.
   - Check scope violations.
   - Check behavior regressions.
   - Check obvious bugs and Godot/GDScript risks.

5. `qa_tester`
   - Produce Godot manual test checklist.
   - Produce regression test items.

6. Orchestrator
   - Summarize all Subagent results for the user.
   - Report changed files, verification status, risks, and next steps.

## Simplified Task Rules

- If the task is read-only analysis, call only `code_explorer` and `reviewer`.
- If the task is QA/testing only, call only `qa_tester`.
- If the task is planning only, call only `pm_planner`.
- If the task involves writing code, scenes, resources, config, or docs, call the full feature workflow unless the user explicitly requests a smaller documentation/rules-only change.
- For documentation/rules updates, the Orchestrator may edit the explicitly requested docs/config files directly if the scope is narrow and no game code is touched.

## Branch Rules

Feature development uses independent branches by default.

Branch naming:

- Skills: `codex/skill-功能名`
- Menus: `codex/menu-功能名`
- Feedback: `codex/feedback-功能名`
- Balance: `codex/balance-功能名`
- QA: `codex/qa-功能名`

Before creating a feature branch, the Orchestrator or `feature_worker` must check:

- Current branch is `main`.
- Worktree is clean.

If either condition is not met, stop and report the problem. Do not continue feature implementation.

`main` must remain stable. Do not auto-merge `main`.

## Default Prohibitions

The Orchestrator and all Subagents are forbidden by default from:

- Automatically committing.
- Automatically pushing.
- Automatically merging `main`.
- Force pushing.
- Modifying unrelated files.
- Developing multiple large features at the same time.
- Modifying `project.godot` without user confirmation.
- Modifying `AGENTS.md`, `docs/**`, `.codex/**`, or `.agent/**` without user confirmation.
- Importing external assets without license confirmation.
- Weakening originality or copyright controls.

## Commit Rules

The Orchestrator may run `git commit` only when the user explicitly says:

- "测试通过，请提交"
- "可以提交"
- Another direct instruction that clearly authorizes committing.

Before committing, the Orchestrator must:

- Run `git status`.
- Confirm the staged and unstaged modification scope.
- Stage only files that belong to the approved task.
- Report the commit hash and committed file list after success.

## Push Rules

The Orchestrator may push only when the user explicitly says:

- "推送到 GitHub"
- Another direct instruction that clearly authorizes pushing.

Pushing must target the current approved feature branch unless the user explicitly says otherwise.

## Scope Rules

- Modify only files authorized by the user or required by the current task.
- Protect existing MVP behavior unless the task explicitly changes it.
- Do not modify `project.godot` unless the task requires it and the user has authorized that scope.
- Do not modify `Main.tscn` unless the task specifically requires main scene wiring and the user has authorized that scope.
- Do not touch game feature code during documentation/rules-only tasks.

## Required Final Output Format

Every fixed workflow must end with this summary:

```text
【主控 Agent 汇总】
- 用户需求：
- 判断的任务类型：
- 使用的 Subagents：
- 当前分支：
- 新增文件：
- 修改文件：
- Review 结果：
- QA 测试清单：
- 风险点：
- 是否需要用户进入 Godot 测试：
- 下一步建议：
```

Keep the summary factual and concise. If a workflow stops early because branch or worktree checks fail, still use the same format and explain the blocker under `风险点` and `下一步建议`.

