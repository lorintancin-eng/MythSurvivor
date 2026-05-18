# MythSurvivor

MythSurvivor 是一个使用 Godot 4.x 开发的 2D 俯视角自动战斗 Roguelite 生存游戏项目，题材灵感来自中国神话。

项目当前处于文档与架构规划阶段。玩法脚本、场景、资源和数值平衡将在后续 MVP 任务中逐步加入。

## 核心方向

- 游戏引擎：Godot 4.x。
- 编程语言：GDScript。
- 玩法形态：俯视角生存场景、自动攻击、敌人波次、升级选择、拾取物和单局成长。
- 题材方向：原创中国神话灵感世界观、敌人、法宝、武器和关卡主题。
- 初始平台：优先面向 PC，除非后续规划调整。

## 原创性政策

本项目不得复刻任何现有商业游戏的素材、角色、UI、地图、命名、成长结构或数值平衡。中国神话只作为宽泛灵感来源。所有设计、资源、调校和表现都必须是 MythSurvivor 的原创内容，或来自许可证兼容的合法资源。

## 规划目录结构

```text
res://
  assets/
    audio/
    fonts/
    sprites/
    vfx/
  docs/
  scenes/
    main/
    gameplay/
    actors/
    ui/
  scripts/
    core/
    gameplay/
    actors/
    combat/
    progression/
    ui/
    utils/
  resources/
    enemies/
    weapons/
    upgrades/
    waves/
    loot/
  tests/
```

当前仓库可能尚未包含以上全部目录。只有在实现任务真正需要时，才创建对应目录。

## 文档说明

- `AGENTS.md`：约束所有 Codex Agent 的项目规则。
- `docs/GDD.md`：游戏设计文档与 MVP 功能目标。
- `docs/ARCHITECTURE.md`：技术架构与模块边界。
- `docs/TASKS.md`：MVP 任务拆解。
- `docs/CODE_STYLE.md`：GDScript 与项目代码风格规则。

## 当前状态

当前文档阶段不应实现任何游戏功能。除非后续任务明确要求，不要添加玩家、敌人、武器、升级、拾取物、地图或 UI 功能脚本。
