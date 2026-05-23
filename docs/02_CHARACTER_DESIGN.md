# 02 角色设计（Character Design）

> 状态：`[骨架]` — 待 Phase 2 从 V0_3_CHARACTERS.md 迁移内容
> 主要内容来源：[archive/v0.3/V0_3_CHARACTERS.md](archive/v0.3/V0_3_CHARACTERS.md)（孙悟空 + 4 神祇预案）

---

## 1. 设计原则

- 每个角色 = 独特玩法变种（不是数值差异）
- 每个角色有专属能量条 + 2-3 件标志武器
- 视觉走"暗黑志怪 + 剪影"风（详见 [07_VISUAL_STYLE_GUIDE.md](07_VISUAL_STYLE_GUIDE.md)）
- 所有人物源自公共领域典籍

## 2. 角色总表

| 编号 | 角色 | 流派定位 | 实施状态 |
|---|---|---|---|
| C00 | 修行者 | 符法系 / 通用 | ✅ v0.1 已实装 |
| C01 | 孙悟空 | 近身旋转 / 群战割草 | 🚧 v0.3 设计中 |
| C02 | 哪吒 | 多武器立体覆盖 | ⏳ v0.4 计划 |
| C03 | 杨戬 | 单体爆发 + 召唤 | ⏳ v0.4 计划 |
| C04 | 女娲 | 元素循环 + 自疗 | ⏳ v0.5 计划 |
| C05 | 盘古 | 蓄力爆发 / 反高频 | ⏳ 终极解锁 |

## 3. 角色基类规范

> [Phase 3 补全] 与 character_base.gd 对齐

### 3.1 共享字段
- `character_id: String`
- `display_name: String`
- `max_health: float`
- `move_speed: float`
- `pickup_radius: float`
- `initial_weapon_id: String`
- `energy_bar_config: Dictionary`
- `unlock_condition: Dictionary`

### 3.2 共享方法
- `_on_energy_full()` — 专属能量条满时触发
- `_get_allowed_upgrades()` — 升级池过滤（返回该角色可用的强化项）

## 4. 角色详细设计

### 4.1 C00 修行者（Cultivator）

> [Phase 2 迁移] 从 v0.2 已实装代码（player.gd + 6 个武器脚本）反向梳理

- **武器组**：追魂符 / 飞剑 / 雷电符咒 / 八卦阵 / 爆裂符 / 山河印
- **专属能量**：无（v0.2 设计，保留作为基准角色）
- **基础属性**：HP 100 / Speed 200 / Pickup 50

### 4.2 C01 孙悟空（Sun Wukong）

> [Phase 2 迁移] 完整内容已在 V0_3_CHARACTERS.md，移到此处

- **武器组**：如意金箍棒 / 金箍棒·变长 / 毫毛分身
- **专属能量**：灵气（击杀积累，满 30 触发七十二变）
- **基础属性**：HP 100 / Speed 230 / Pickup 60
- **七十二变**：3 秒无敌 + 伤害+50% + 移速+30%
- 详细武器数值与强化路径见 [04_SKILL_DESIGN.md](04_SKILL_DESIGN.md)

### 4.3 C02 哪吒（Nezha）— 预案

> [Phase 3 补全]

### 4.4 C03 杨戬（Yang Jian）— 预案

> [Phase 3 补全]

### 4.5 C04 女娲（Nvwa）— 预案

> [Phase 3 补全]

### 4.6 C05 盘古（Pangu）— 预案

> [Phase 3 补全]

## 5. 角色解锁条件

| 角色 | 解锁条件 |
|---|---|
| 修行者 | 开局默认 |
| 孙悟空 | v0.3 起开局默认 |
| 哪吒 | 通关 1·荒山古道 |
| 杨戬 | 通关 2·幽都鬼市 |
| 女娲 | 通关 3·昆仑残境 |
| 盘古 | 全角色通关 + 击败终局妖王 |

## 6. 角色平衡基线

> [Phase 3 补全] 各角色 5 分钟单局期望 DPS、生存率、平均通关时间

## 7. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | 0.1 | 骨架建立，待 Phase 2 迁移 V0_3 内容 |
