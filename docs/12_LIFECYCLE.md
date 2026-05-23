# 12 任务 / 版本生命周期 + DoR + DoD

> 状态：`[骨架 + 完整生命周期]`
> 与 [10_TASK_BACKLOG.md](10_TASK_BACKLOG.md), [11_ACCEPTANCE_CHECKLIST.md](11_ACCEPTANCE_CHECKLIST.md) 配套

---

## 1. 任务生命周期

```
想法 → DoR 检查 → 待办 → 进行中 → review → QA → 完成 → 关闭
              ↑                                       ↓
              └────────── 回炉（任意阶段）────────────┘
```

### 1.1 状态定义

| 状态 | 含义 | 谁能改 |
|---|---|---|
| 💡 想法 | 用户/团队提出，尚未拆分 | 用户 |
| ⏳ 待办 | 通过 DoR，可被领取 | pm-planner / 用户 |
| 🚧 进行中 | feature-worker 实施中 | 主控 |
| 🔍 review | 等待 reviewer 审查 | reviewer |
| 🧪 QA | 等待 qa-tester 输出清单或手测 | qa-tester / 用户 |
| ✅ 完成 | 通过 DoD | 主控 |
| ❌ 取消 | 放弃此任务 | 用户 |

### 1.2 状态流转规则

- 任何状态可回退到 "进行中"（发现问题）
- "完成" 只能由通过全部 DoD 后进入
- "取消" 需要用户明确授权

## 2. DoR — Definition of Ready（可开始定义）

任务从 "想法" → "待办" 必须满足：

- [ ] 任务有明确名称与范围
- [ ] 验收标准可测试（不是模糊描述）
- [ ] 允许 / 禁止修改文件清晰
- [ ] 依赖任务已识别
- [ ] 优先级与估算已定
- [ ] 风险已初步分析
- [ ] 对应 ROADMAP 版本已明确

由 **pm-planner** 输出后即视为 DoR 通过。

## 3. DoD — Definition of Done（完成定义）

详见 [11_ACCEPTANCE_CHECKLIST.md](11_ACCEPTANCE_CHECKLIST.md) §2。

简要：代码完成 + reviewer 通过 + 主流程手测通过 + 通用 smoke test 通过 + 文档同步 + 用户授权提交。

## 4. 任务 5 步工作流（feature 任务）

```
1. pm-planner    → 输出任务规划（DoR）
2. code-explorer → 摸清现有代码，输出最小改动方案
3. feature-worker → 实施
4. reviewer      → 审查 diff
5. qa-tester     → 输出手测清单
6. 主控          → 汇总 + 等待用户授权 commit / push
```

简化任务（read-only / pure planning / QA only）见 [.codex/ORCHESTRATOR.md](../.codex/ORCHESTRATOR.md)。

## 5. 版本生命周期

```
规划 → 拆分 → 开发 → 整合 → QA → 发布 → 复盘
```

### 5.1 各阶段责任

| 阶段 | 责任 | 输出 |
|---|---|---|
| 规划 | 用户 / 设计师 | 版本设计文档（如 V0_3_CHARACTERS.md） |
| 拆分 | pm-planner | 任务列表填入 10_TASK_BACKLOG.md |
| 开发 | feature-worker | 各任务完成 |
| 整合 | 主控 | 所有任务合入主线（main 或 develop） |
| QA | qa-tester + 用户 | QA 实例记录 |
| 发布 | 用户授权下主控执行 | tag + GitHub Release |
| 复盘 | 用户 / 主控 | 经验、风险记录、ROADMAP 调整 |

### 5.2 版本发布门禁

详见 [14_RELEASE_PROCESS.md](14_RELEASE_PROCESS.md)。

## 6. 紧急变更流程（Hotfix）

线上发现严重 bug 时：

1. 立即创建 hotfix 分支：`hotfix/v0.x.y-描述`
2. 跳过 pm-planner（用户直接说明问题）
3. 必须经过 reviewer
4. 可简化 QA 至关键回归
5. 修复后 tag 为 `v0.x.y+1`
6. 事后补 ADR 记录此次紧急决策

## 7. 范围变更流程

任务进行中发现范围需调整：

1. feature-worker 立即停止
2. 主控向用户报告：当前进度 / 发现的问题 / 范围调整建议
3. 用户决策：
   - 继续原范围 → 继续
   - 调整范围 → 回到 pm-planner 重新规划
   - 取消任务 → 标 ❌ 取消
4. 范围变更必须记录在任务备注里

## 8. 任务取消条件

- 需求消失或变更
- 技术不可行
- 优先级下降
- 重复任务

取消必须由用户明确确认。

## 9. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | 0.1 | 首次建立 |
