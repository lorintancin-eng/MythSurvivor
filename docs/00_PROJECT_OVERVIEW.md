# MythSurvivor 项目总览（PMF v1 入口）

> **本文档是 MythSurvivor 项目管理框架（Project Management Framework, PMF v1）的顶层入口。**
> 第一次接触本项目的人 / 新加入的 Agent，从这里开始。

---

## 0. 文档元信息

| 字段 | 值 |
|---|---|
| 项目名 | MythSurvivor |
| 引擎 | Godot 4.x |
| 语言 | GDScript |
| 类型 | 中国神话题材、2D 俯视角、自动战斗、Roguelite 生存游戏 |
| 当前版本 | v0.2（功能完成，发布暂缓） |
| 在研版本 | v0.3（角色系统 + 孙悟空，设计阶段） |
| PMF 版本 | v1（首次建立） |
| PMF 落地日期 | 2026-05-23 |
| 仓库 | https://github.com/lorintancin-eng/MythSurvivor |

---

## 1. 项目愿景（一句话）

> 玩家在阴冷压迫的山海劫境中，化身上古神祇与凡间修行者，吸收修为、悟得法术、封印镇妖碑、对抗妖潮，并在 5 分钟后迎战妖王，完成一关又一关的镇妖试炼。

完整愿景见 [GDD.md](GDD.md)。

---

## 2. 当前项目状态摘要

### 2.1 已完成（截至 PMF v1 落地）

- **MVP v0.1**：玩家、敌人、武器、经验、升级、HUD、Game Over 全套基础循环
- **v0.2 功能**：3 法宝（飞剑/雷霆/八卦阵/爆裂符/山河印）+ 关卡导演 + 镇妖碑 + 精英 + 荒年兽 Boss + 暗黑志怪 UI 文案 + 数值平衡
- **v0.3 设计稿**：角色系统设计 + 孙悟空全套设计（[02_CHARACTER_DESIGN.md](02_CHARACTER_DESIGN.md)）
- **PMF v1**：本文档体系本身

### 2.2 进行中

- v0.3 角色系统**实施**（孙悟空代码 / UI / 升级池过滤）
- PMF v1 后续 Phase（内容迁移与补全）

### 2.3 暂缓

- v0.2 正式发布（手动 QA + tag + GitHub Release）
- v0.4+ 其他神祇实施（哪吒 / 杨戬 / 女娲 / 盘古）

---

## 3. 文档地图（PMF v1 全景）

### 3.1 设计层 — "做什么样的游戏"

| 编号 | 文档 | 内容 |
|---|---|---|
| 01 | [01_STORY_BIBLE.md](01_STORY_BIBLE.md) | 世界观、故事背景、设定圣经 |
| 02 | [02_CHARACTER_DESIGN.md](02_CHARACTER_DESIGN.md) | 角色设计（修行者 + 5 神祇） |
| 03 | [03_CORE_GAMEPLAY.md](03_CORE_GAMEPLAY.md) | 核心玩法、循环、机制 |
| 04 | [04_SKILL_DESIGN.md](04_SKILL_DESIGN.md) | 技能/武器/特效设计规范 |
| 05 | [05_ENEMY_DESIGN.md](05_ENEMY_DESIGN.md) | 怪物 / Boss / 精英 / 词缀 |
| 06 | [06_LEVEL_DESIGN.md](06_LEVEL_DESIGN.md) | 关卡 / 镇妖碑 / 节奏曲线 |
| 07 | [07_VISUAL_STYLE_GUIDE.md](07_VISUAL_STYLE_GUIDE.md) | 美术风格（暗黑志怪 + 剪影规范） |
| 08 | [08_UI_UX_GUIDE.md](08_UI_UX_GUIDE.md) | UI / 交互 / 术语包 |

### 3.2 管理层 — "怎么计划与跟进"

| 编号 | 文档 | 内容 |
|---|---|---|
| 09 | [09_ROADMAP.md](09_ROADMAP.md) | 跨版本路线图（v0.1 → 1.0） |
| 10 | [10_TASK_BACKLOG.md](10_TASK_BACKLOG.md) | 跨版本任务待办池 |
| 11 | [11_ACCEPTANCE_CHECKLIST.md](11_ACCEPTANCE_CHECKLIST.md) | 通用验收清单标准 |

### 3.3 流程层 — "怎么做事"

| 编号 | 文档 | 内容 |
|---|---|---|
| 12 | [12_LIFECYCLE.md](12_LIFECYCLE.md) | 任务/版本生命周期 + DoR + DoD |
| 13 | [13_BRANCHING.md](13_BRANCHING.md) | 分支策略 |
| 14 | [14_RELEASE_PROCESS.md](14_RELEASE_PROCESS.md) | 通用发布流程 + 门禁 |
| 15 | [15_PULL_REQUEST_GUIDE.md](15_PULL_REQUEST_GUIDE.md) | PR 流程 + 模板 |
| 16 | [16_RISK_REGISTRY.md](16_RISK_REGISTRY.md) | 风险 / 技术债登记簿 |

### 3.4 子目录

| 路径 | 用途 |
|---|---|
| [decisions/](decisions/) | ADR — 架构决策记录（每个重大决策一个文件） |
| [templates/](templates/) | 复用模板（任务模板、ADR 模板、QA 清单模板等） |
| [archive/](archive/) | 历史/已合并文档归档（按版本分组） |

### 3.5 保留的基础规范文档（不动）

| 文档 | 内容 |
|---|---|
| [GDD.md](GDD.md) | 战略愿景 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 技术架构 |
| [CODE_STYLE.md](CODE_STYLE.md) | 代码风格 |

### 3.6 Agent 体系文档（在仓库根目录，不动）

| 文档 | 内容 |
|---|---|
| [../AGENTS.md](../AGENTS.md) | Agent 角色与职责 |
| [../.codex/ORCHESTRATOR.md](../.codex/ORCHESTRATOR.md) | 主控编排规则 |
| [../.codex/config.toml](../.codex/config.toml) | 项目配置 |
| [../.codex/agents/](../.codex/agents/) | 各 Subagent TOML 配置 |

---

## 4. 按角色快速入口

| 你是谁 | 你应该先读 |
|---|---|
| **新加入的 Agent / 开发者** | 本文档 → [AGENTS.md](../AGENTS.md) → [12_LIFECYCLE.md](12_LIFECYCLE.md) → [13_BRANCHING.md](13_BRANCHING.md) |
| **想了解游戏要做什么** | [GDD.md](GDD.md) → [01_STORY_BIBLE.md](01_STORY_BIBLE.md) → [03_CORE_GAMEPLAY.md](03_CORE_GAMEPLAY.md) |
| **要实现一个新功能** | [10_TASK_BACKLOG.md](10_TASK_BACKLOG.md) → [12_LIFECYCLE.md](12_LIFECYCLE.md) → 启动主控 5 步工作流 |
| **要做美术 / UI** | [07_VISUAL_STYLE_GUIDE.md](07_VISUAL_STYLE_GUIDE.md) + [08_UI_UX_GUIDE.md](08_UI_UX_GUIDE.md) |
| **要写技能 / 武器** | [04_SKILL_DESIGN.md](04_SKILL_DESIGN.md) + [CODE_STYLE.md](CODE_STYLE.md) |
| **要做 QA / 测试** | [11_ACCEPTANCE_CHECKLIST.md](11_ACCEPTANCE_CHECKLIST.md) → 当前版本 QA 实例 |
| **要发布版本** | [14_RELEASE_PROCESS.md](14_RELEASE_PROCESS.md) → [09_ROADMAP.md](09_ROADMAP.md) |
| **要做架构决策** | [decisions/](decisions/) → [decisions/ADR_TEMPLATE.md](decisions/ADR_TEMPLATE.md) |
| **发现 bug / 想报问题** | [16_RISK_REGISTRY.md](16_RISK_REGISTRY.md)（如果是技术债）或新建 GitHub Issue |

---

## 5. 主控 + Subagent 工作流（一句话）

```
用户给需求
   ↓
主控 Agent 分类任务
   ↓
功能开发任务 → 5 步固定流程：
   pm-planner → code-explorer → feature-worker → reviewer → qa-tester
   ↓
主控汇总 + 等待用户授权 commit / push / merge
```

详见 [AGENTS.md](../AGENTS.md) 与 [.codex/ORCHESTRATOR.md](../.codex/ORCHESTRATOR.md)。

---

## 6. PMF v1 落地状态

| Phase | 内容 | 状态 |
|---|---|---|
| Phase 1 | 全部 16+ 文档骨架创建 + 子目录建立 | ✅ 完成（commit 86abf5b） |
| Phase 2 | 现有 5 个老文档移到 archive/v0.2/ 和 v0.3/ | ✅ 完成（commit 519d48d） |
| Phase 3-1 | 02 角色 + 04 技能 + 10 任务池 内容补全 | ✅ 完成（commit 1de2c96） |
| Phase 3-2 | 03 玩法 + 05 怪物 + 06 关卡 内容补全 | ✅ 完成（本 commit） |
| Phase 3-3 | 01 故事 + 07 美术 + 08 UI 内容补全 | ⏳ 待启动 |

每个文档头部标注其内容状态：`[骨架]` / `[内容迁移自 xxx]` / `[完整]`。

---

## 7. 原创性约束（贯穿全项目）

**所有玩法、视觉、命名、数值、特效必须原创或基于公共领域素材**。

- ✅ 可用：中国公共领域神话典籍（《西游记》《封神演义》《山海经》《淮南子》等）的人物形象、武器、故事
- ❌ 不可：复制商业游戏（《黑神话：悟空》《阴阳师》《王者荣耀》《吸血鬼幸存者》等）的视觉表达、技能命名风格、数值平衡、UI 布局

详见 [GDD.md](GDD.md) "原创性规则" 与 [AGENTS.md](../AGENTS.md) "原创性政策"。

---

## 8. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | PMF v1 落地 | 首次建立项目管理框架，创建本入口与 16+ 个核心文档骨架 |
