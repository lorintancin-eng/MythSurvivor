# 架构决策记录（Architecture Decision Records, ADR）

> 本目录用于记录项目中**有长期影响的技术与设计决策**，避免决策遗忘。

---

## 1. 何时写 ADR

满足任一就应该写：

- 影响多个模块的架构选择（如"用 Resource 而非 JSON 配置敌人"）
- 难以回退的技术决策（如"用 Godot 4.x 而非 Unity"）
- 推翻之前决策的新方向（如"v0.3 引入角色基类重构 v0.2 玩家"）
- 重大权衡（如"v0.2 PR#2 用本地 merge 替代 GitHub PR"）
- 暂缓 / 不做的决定（如"v0.2 暂不发布"）

## 2. 何时不写 ADR

- 实施细节（小函数命名、缩进调整）
- 标准做法（用 GDScript 类型化）
- 临时实验（实验后会撤销）

## 3. ADR 编号

按时间顺序，4 位数字补零：

- `0001-godot4-gdscript.md`
- `0002-pmf-v1-architecture.md`
- `0003-character-system-v03.md`

编号一旦分配不复用。

## 4. ADR 状态

每个 ADR 头部标注：

| 状态 | 含义 |
|---|---|
| Proposed | 提议中，待评审 |
| Accepted | 已采纳，正在执行 |
| Deprecated | 已废弃，但保留记录 |
| Superseded | 被另一个 ADR 取代 |

## 5. 模板

新建 ADR 时基于 [ADR_TEMPLATE.md](ADR_TEMPLATE.md) 复制。

## 6. 已有 ADR

| 编号 | 标题 | 状态 |
|---|---|---|
| [0001](0001-godot4-gdscript.md) | 选择 Godot 4.x + GDScript | Accepted |
| 0002 | （PMF v1 架构本身，待 Phase 2 补） | Proposed |
| 0003 | （v0.3 角色系统方向，待 Phase 2 补） | Proposed |

## 7. 如何引用 ADR

在其他文档 / commit message / 代码注释中引用：

```
参见 ADR-0001: docs/decisions/0001-godot4-gdscript.md
```
