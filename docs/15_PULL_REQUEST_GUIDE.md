# 15 Pull Request 流程与模板

> 状态：`[骨架 + PR 模板]`
> 与 [13_BRANCHING.md](13_BRANCHING.md) §5 配套

---

## 1. 何时用 PR

| 情况 | 选择 |
|---|---|
| 改动 > 500 行 或 涉及核心系统 | ✅ PR |
| 改动 < 100 行、单文件、低风险 | 本地合也可（保留 PR 选项） |
| 文档 / 规则改动 | 本地合直接 push 也可 |
| 紧急 hotfix | 先合，事后补 PR 记录 |
| 实验性大改动 | ✅ PR（draft 模式） |

## 2. PR 创建前置

- [ ] 分支已 push 到 origin
- [ ] 通过 reviewer subagent 审查
- [ ] 通过 qa-tester 输出测试清单
- [ ] 本地编辑器跑过 smoke test
- [ ] 用户已确认要走 PR 流程

## 3. PR 标题规范

```
<type>: <简短描述（< 50 字符）>
```

| type | 含义 |
|---|---|
| feat | 新功能 |
| fix | bugfix |
| refactor | 重构（行为不变） |
| docs | 文档 |
| perf | 性能 |
| style | 格式 / 代码风格 |
| test | 测试 |
| chore | 其他杂项 |
| release | 发布相关 |

示例：
- `feat: 孙悟空角色系统 + 灵气能量条`
- `fix: 镇妖碑生成位置偶尔超出地图`
- `refactor: 玩家武器初始化拆为 character_base`

中文标题也接受（v0.2 PR#2 用了中文标题）。

## 4. PR Body 模板

````markdown
## Summary

<1-3 段说明本次 PR 做了什么、为什么>

## 变更范围

- 文件：X 个，+Y / -Z 行
- 涉及模块：[模块 1] [模块 2]
- 涉及版本：v0.x

## 关键改动

- ✨ 新增 ...
- 🔄 修改 ...
- 🐛 修复 ...
- 📝 文档 ...

## Test plan

- [ ] Godot 编辑器打开无报错
- [ ] [具体功能验证 1]
- [ ] [具体功能验证 2]
- [ ] 回归项：[相关已有功能 1]
- [ ] 回归项：[相关已有功能 2]

## 风险与已知问题

<本次改动可能影响哪些已有功能 / 哪些边界场景未覆盖>

## 关联文档

- [设计文档链接]
- [任务编号: T0xx]
- [ADR 链接（如有）]

## 审查重点

请帮我重点看：
- [ ] [审查点 1]
- [ ] [审查点 2]
````

## 5. Reviewer 审查清单

收到 PR 后审查者应核对：

- [ ] 改动范围与 PR 描述一致
- [ ] 无越界修改（不在白名单的文件）
- [ ] 代码风格符合 [CODE_STYLE.md](CODE_STYLE.md)
- [ ] GDScript 类型化、命名规范
- [ ] 无明显 bug / 边界遗漏
- [ ] 无场景引用断裂
- [ ] 性能无明显退化
- [ ] 涉及的文档已同步
- [ ] Test plan 合理

## 6. PR 合并策略

- 默认 **Merge commit**（保留 commit 历史）
- 例外：单 commit 小 PR 可 Squash
- **不推荐 rebase merge**（会改写历史）

## 7. PR 关闭情况

| 状态 | 含义 |
|---|---|
| Merged | 已合入 base 分支 |
| Closed | 未合并就关闭（取消 / 重做） |

GitHub 自动检测：如果分支所有 commit 都已在 base 分支上，PR 会自动标 MERGED 而不是 closed（如 v0.2 PR#2 的本地合并案例）。

## 8. GitHub PR Template 文件

> 建议同步创建 `.github/pull_request_template.md`，让所有 PR 默认应用本模板

```bash
mkdir -p .github
# 把 §4 的模板写入 .github/pull_request_template.md
```

（本次 PMF v1 Phase 1 不创建 .github 模板，留待用户决定）

## 9. PR 互动礼节

- 评论保持具体（"这里 NPE 风险"，而非"这有问题"）
- 提议改动给出代码示例或具体方案
- 接受 review 提的意见 → 在新 commit 中回应（不重写 history）

## 10. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | 0.1 | 首次建立 |
