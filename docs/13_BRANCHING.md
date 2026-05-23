# 13 分支策略

> 状态：`[骨架 + 完整规则]`
> 整合自 [AGENTS.md](../AGENTS.md) §分支规则 + [.codex/ORCHESTRATOR.md](../.codex/ORCHESTRATOR.md) §Branch Rules

---

## 1. 分支总览

```
main                 ← 始终稳定，发布基线
  ├── codex/xxx-yyy  ← 功能开发分支（5 步工作流）
  ├── hotfix/x.y.z   ← 紧急修复分支
  ├── docs/xxx       ← 文档/规则更新分支（可选，小改动可直接在 main）
  └── claude/xxx     ← Claude Code worktree 临时分支（不入主线）
```

## 2. 分支命名规范

| 类型 | 命名格式 | 示例 |
|---|---|---|
| 技能 | `codex/skill-技能名` | `codex/skill-bagua-array` |
| 角色 | `codex/character-角色名` | `codex/character-sun-wukong` |
| 关卡 | `codex/stage-关卡名` | `codex/stage-ghost-market` |
| Boss | `codex/boss-Boss名` | `codex/boss-famine-beast` |
| 敌人 | `codex/enemy-敌人名` | `codex/enemy-paper-doll` |
| 菜单 | `codex/menu-功能名` | `codex/menu-pause` |
| 反馈/特效 | `codex/feedback-功能名` | `codex/feedback-hit-flash` |
| 平衡 | `codex/balance-范围` | `codex/balance-stage9` |
| QA | `codex/qa-范围` | `codex/qa-v02-checklist` |
| 文档/规则 | `codex/docs-主题` | `codex/docs-pmf-v1` |
| 紧急修复 | `hotfix/版本号` | `hotfix/v0.2.1` |

## 3. main 分支规则

- **永远保持稳定**
- 不允许直接在 main 上写代码（除文档 / 规则更新允许）
- 不允许 force push
- 不允许自动合并

## 4. 功能分支规则

### 4.1 创建前提
- 当前分支是 main
- `git status` 工作区干净（除 untracked 的 `.claude/` `CLAUDE.md`）
- 任务已通过 DoR

### 4.2 生命周期
```
基于 main 创建 → 实施 → 内部 commit → push 到 origin → PR 或本地合 → 合入 main → 分支删除
```

### 4.3 删除时机
- 已合并入 main
- 任务取消（用户确认后）

## 5. 合并策略

### 5.1 merge vs rebase

| 场景 | 策略 |
|---|---|
| 单 commit 小改动 | fast-forward 或 squash |
| 多 commit 语义清晰 | `--no-ff` merge commit |
| 长期 feature 分支 | 定期 rebase main 保持线性 |

### 5.2 PR vs 本地合

| 场景 | 选择 |
|---|---|
| 改动 > 500 行 / 涉及核心系统 | PR（GitHub review） |
| 改动 < 100 行 / 单文件 | 本地合 + push 也可 |
| 紧急 hotfix | 本地合，事后补 PR 记录 |

## 6. 禁止项

- ❌ 自动 commit / push / merge / force push
- ❌ 跳过 hook（--no-verify）
- ❌ 改 git config
- ❌ 在不干净工作区开新分支
- ❌ 跨分支带未提交改动

## 7. Worktree 规则

- 主仓库始终在 `D:/game/game`
- Claude Code 临时 worktree 在 `D:/game/game/.claude/worktrees/`
- 不同 worktree 不能 checkout 同一分支
- worktree 用完应清理（`git worktree remove`）

## 8. 远端规则

- 唯一远端：`origin` → https://github.com/lorintancin-eng/MythSurvivor
- push 必须明确指定分支（避免误推）
- push 前确认本地 commit 不含敏感文件

## 9. 紧急情况

| 问题 | 处理 |
|---|---|
| 分支误推到 main | 立即报告用户，决定 revert 还是手动修复 |
| 合并冲突 | 由 feature-worker 解决，reviewer 复查 |
| 远端被他人改动 | fetch + 重新规划合并策略 |

## 10. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | 0.1 | 首次建立 |
