# 10 跨版本任务待办池（Task Backlog）

> 状态：`[骨架 + 部分迁移]` — Phase 2 时将 v0.2 TASKS.md 已完成项整合进来
> 与 [09_ROADMAP.md](09_ROADMAP.md) 双向引用，与 [12_LIFECYCLE.md](12_LIFECYCLE.md) 配合

---

## 1. 任务格式约定

每个任务遵循 [templates/TASK_TEMPLATE.md](templates/TASK_TEMPLATE.md) 格式：

```markdown
### T0xx 任务名

- 版本：v0.x
- 状态：⏳ 待办 / 🚧 进行中 / 🔍 review / ✅ 完成 / ❌ 取消
- 优先级：P0 / P1 / P2
- 估算：S / M / L / XL
- 负责人：（agent 或用户）
- 分支：codex/xxx-xxx
- 依赖：T0yy, T0zz
- 验收标准：见 [11_ACCEPTANCE_CHECKLIST.md](11_ACCEPTANCE_CHECKLIST.md)
- 备注：
```

## 2. 任务编号规则

- T001-T099：v0.1 MVP
- T100-T199：v0.2
- T200-T299：v0.3
- T300-T399：v0.4
- 以此类推

PMF 自身任务 T9xx 系列（如 T901 = 建立 PMF）。

## 3. 状态汇总

| 版本 | 待办 | 进行中 | Review | 完成 | 取消 |
|---|---|---|---|---|---|
| v0.1 | 0 | 0 | 0 | 全部 ✅ | 0 |
| v0.2 | 2 | 0 | 0 | 31 | 0 |
| v0.3 | 待 Phase 2 拆分 | — | — | — | — |
| v0.4+ | 待规划 | — | — | — | — |

## 4. v0.1 任务（已完成）

> [Phase 2 不迁移历史 v0.1 任务，归档参考 archive/v0.2/TASKS.md]

## 5. v0.2 任务（已完成 31 / 33）

> [Phase 2 从 archive/v0.2/TASKS.md 整合]

未完成 2 项：
- T169 执行 v0.2 手动验收（用户暂缓）
- T170 发布 v0.2 tag + GitHub Release（用户暂缓）

## 6. v0.3 任务（待拆分）

> [Phase 3 由 pm-planner 基于 V0_3_CHARACTERS.md §7.1 拆分]

预期任务：
- T200 角色基类 + 角色选择 UI
- T201 修行者代码重构归位
- T202 孙悟空角色脚本 + 灵气能量
- T203 七十二变机制
- T204 如意金箍棒武器
- T205 金箍棒·变长武器
- T206 毫毛分身武器
- T207 升级池过滤逻辑
- T208 HUD 专属能量条
- T209 默认角色切换
- T210 v0.3 QA 手测清单

## 7. v0.4+ 任务（待规划）

> [Phase 3 由 pm-planner 基于 02 / 05 / 06 文档拆分]

## 8. PMF 自身任务

| ID | 任务 | 状态 |
|---|---|---|
| T901 | PMF v1 Phase 1 骨架 | 🚧 本次进行中 |
| T902 | PMF v1 Phase 2 内容迁移 | ⏳ 待用户授权 |
| T903 | PMF v1 Phase 3 内容补全 | ⏳ 待用户授权 |
| T904 | 老 v0.2 文档归档到 archive/ | ⏳ Phase 2 一起做 |

## 9. 任务领取规则

- 主控 Agent 接到用户需求 → 在此处查找匹配任务或创建新任务
- 启动 5 步工作流前应先看任务是否已存在
- 任务状态变更时同步更新本表

## 10. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | 0.1 | 首次建立 |
