# 哪吒 + 杨戬 人物设计稿（v0.6）

> **状态**：✅ 设计已定稿（用户 2026-05-26 全程授权，主控采纳 pm-planner 6 决策）
> **关联**：[02_CHARACTER_DESIGN.md](02_CHARACTER_DESIGN.md) §4.3/§4.4 / [09_ROADMAP.md](09_ROADMAP.md) §3.6 / [ADR-0003](decisions/0003-sun-wukong-active-skills.md)
> **目标版本**：v0.6（继 L003 关卡完成后）

---

## 0. 核心设计前提

⚠️ **哪吒/杨戬是全自动战斗角色**（与修行者一致：自动攻击 + 自动技能，玩家只控移动 + 升级三选一）。

- **不继承 ActiveSkillCharacter**（那是孙悟空主动技能特例，见 ADR-0003）
- 直接继承 `CharacterBase`，模式接近修行者
- 专属能量条用 `energy_bar_config`（`auto_trigger` 控制满时是否自动触发）

---

## 1. 六大关键决策（已拍板）

| # | 决策 | 选择 |
|---|---|---|
| D01 | 实施顺序 | **先哪吒后杨戬**（哮天犬召唤最复杂，哪吒作模板）|
| D02 | 三昧真火触发 | 受伤累积，满 100 设 `_fire_ready`，下次攻击爆发后清零（`consume_fire()`）|
| D03 | 天眼槽留蓄 | `auto_trigger=false`，满了不自动触发，下次三尖刀攻击消耗（`consume_heaven_eye()`）|
| D04 | 哮天犬召唤 | 复用 HairCloneUnit 模式（新建 `XiaoTianQuanUnit`，常驻而非按键召唤）|
| D05 | 武器实现 | 全部新建 6 件（不复用修行者武器）|
| D06 | 角色选择 UI | 扩展为 4 按钮（修行者/孙悟空/哪吒/杨戬），GridContainer 2×2 |

---

## 2. 哪吒「火劫童子」完整设计

### 2.1 基础属性

| 属性 | 值 |
|---|---|
| character_id | "nezha" |
| display_name | "火劫童子" |
| max_health | 90（脆皮高输出）|
| move_speed | 220（最快）|
| pickup_radius | 55 |
| initial_weapon_id | "huo_jian_qiang" |
| element | "fire"（v0.7 启用）|

### 2.2 专属能量：三昧真火

| 字段 | 实现 |
|---|---|
| current_true_fire | 0.0~100.0 |
| 充能 | `_on_damaged(amount)` → +10（受伤回能）|
| 满时 | `_on_energy_full()` 设 `_fire_ready = true` + emit energy_full_triggered |
| 爆发 | 下次攻击：damage ×1.3 + range ×1.5（单次）|
| 触发后 | current_true_fire = 0，_fire_ready = false |
| energy_bar_config | `{max_value: 100, fill_color: Color(1,0.3,0), label: "三昧真火", auto_trigger: false, value_field: "current_true_fire"}` |
| 公开方法 | `consume_fire() -> bool`（武器攻击前调用）|

### 2.3 三武器

#### W201 火尖枪（初始）
| Lv | 模式 | dmg | cd |
|---|---|---|---|
| 1 | 前方 3 发火球穿透 1 + 0.5s 灼烧圈(8/s) | 12 | 1.6 |
| 2 | 5 发，灼烧 +4/s | 14 | 1.5 |
| 3 | 穿透 +1，灼烧 0.8s | 16 | 1.4 |
| 4 | 回旋追踪 + 灼烧范围 +20% | 18 | 1.3 |

#### W202 混天绫（升级解锁）
| Lv | 模式 | dmg | cd |
|---|---|---|---|
| 1 | 半径 80 环形 + 减速 40%/1.5s + DoT 6/s | 6 | 3.0 |
| 2 | 半径 +20，减速 50%/2.0s | 8 | 2.8 |
| 3 | 命中束缚 0.5s | 10 | 2.6 |
| 4 | 半径 +20，DoT +4/s，束缚 +0.3s | 12 | 2.4 |

#### W203 乾坤圈（升级解锁）
| Lv | 模式 | dmg | cd |
|---|---|---|---|
| 1 | 锁定最近敌人回旋镖，折返双段 | 15 | 2.2 |
| 2 | 折返 40 AOE | 18 | 2.0 |
| 3 | 双发（锁前 2 近）| 22 | 2.0 |
| 4 | 三才合击（命中召唤 30% 火尖枪+混天绫）| 25 | 1.8 |

### 2.4 哪吒升级池（12 项专属 + 4 通用）

```
nezha_fire_spear_damage / cooldown / burn_damage
nezha_hun_tian_ling_radius / dot / cooldown
nezha_qian_kun_damage / cooldown
nezha_true_fire_charge (+15 而非 +10) / true_fire_burst_range
nezha_unlock_hun_tian_ling / unlock_qian_kun
```

---

## 3. 杨戬「二郎真君」完整设计

### 3.1 基础属性

| 属性 | 值 |
|---|---|
| character_id | "yang_jian" |
| display_name | "二郎真君" |
| max_health | 110（坦输出）|
| move_speed | 190 |
| pickup_radius | 45 |
| initial_weapon_id | "san_jian_dao" |
| element | "metal"（v0.7）|

### 3.2 专属能量：天眼槽

| 字段 | 实现 |
|---|---|
| current_heaven_eye | 0.0~100.0 |
| 充能 | `_process` 每秒 +2；`_on_kill` 小怪 +3 / 精英 +30 |
| 满时 | 设 `_eye_ready = true`（不自动消耗，auto_trigger=false）|
| 爆发 | 下次三尖刀攻击：小怪即死，精英/Boss ×4 伤害 |
| 触发后 | current_heaven_eye = 0，_eye_ready = false |
| energy_bar_config | `{max_value: 100, fill_color: Color(0.8,0.9,1.0), label: "天眼槽", auto_trigger: false, value_field: "current_heaven_eye"}` |
| 公开方法 | `consume_heaven_eye() -> bool` |

### 3.3 三武器

#### W301 三尖两刃刀（初始）
| Lv | 模式 | dmg | cd |
|---|---|---|---|
| 1 | 扇形 90° 三段斩 + 击退 | 18 | 2.0 |
| 2 | 扇形 110°，第三段 ×1.3 | 22 | 1.9 |
| 3 | 四段，第四段 AOE 40 | 26 | 1.9 |
| 4 | 天眼一斩额外 80 范围 50% 溅射 | 30 | 1.8 |

天眼一斩：`consume_heaven_eye()` 返回 true 时小怪即死/精英 Boss ×4。

#### W302 哮天犬（升级解锁，召唤）
| Lv | 模式 | dmg |
|---|---|---|
| 1 | 召唤 1 只常驻，咬击(cd 1.2s) + 减速 30%/1s | 10 |
| 2 | 咬击 +6，减速 40%，stun 0.3s | 16 |
| 3 | 第 2 只哮天犬 | 16 |
| 4 | 死亡爆裂 AOE(60/20dmg) + 3s 复活 | 16 |

复用 HairCloneUnit 模式，新建 `XiaoTianQuanUnit`（常驻 + 减速 + 爆裂复活）。

#### W303 天眼真火（升级解锁，等级≥3）
| Lv | 模式 | dmg | cd |
|---|---|---|---|
| 1 | 全屏锁最低血敌人，激光 10 段 | 25 | 8.0 |
| 2 | +10，锁 2 目标 | 35 | 7.5 |
| 3 | 激光 +5 段 | 40 | 7.0 |
| 4 | 锁精英/Boss ×2 | 45 | 6.5 |

### 3.4 杨戬升级池（12 项专属 + 4 通用）

```
yangjian_dao_damage / cooldown / arc
yangjian_dog_damage / slow / cooldown
yangjian_eye_fire_damage / cooldown
yangjian_eye_charge_kill (+5) / eye_charge_time (+3/s)
yangjian_unlock_xiao_tian_quan / unlock_heaven_eye_fire
```

---

## 4. 任务拆分（12 任务）

### 前置（公共）
- **NEZHA-PRE**：HUD 能量条通用化（`hud.gd:_update_energy_bar` 从 `energy_bar_config["value_field"]` 读字段名，孙悟空补 `value_field: "current_lingqi"`）

### 哪吒批次
- **N01**：nezha.gd + PlayerNezha.tscn（三昧真火 + consume_fire）
- **N02**：火尖枪 W201
- **N03**：混天绫 W202
- **N04**：乾坤圈 W203
- **N05**：哪吒升级池接入（player.gd）

### 杨戬批次
- **Y01**：yangjian.gd + PlayerYangJian.tscn（天眼槽 + consume_heaven_eye）
- **Y02**：三尖两刃刀 W301
- **Y03**：哮天犬 W302（XiaoTianQuanUnit + 控制器）
- **Y04**：天眼真火 W303
- **Y05**：杨戬升级池接入

### UI
- **UI01**：角色选择面板扩展 4 按钮

---

## 5. 文件白名单/黑名单

### 白名单（按任务）
- NEZHA-PRE：`scripts/ui/hud.gd`（仅 _update_energy_bar）
- N01：`scripts/character/nezha.gd` + `scenes/player/PlayerNezha.tscn`
- N02-N04：`scripts/weapon/nezha/*.gd`
- N05/Y05：`scripts/player/player.gd`（仅 _get_upgrade_pool + _apply_upgrade 内新增分支）
- Y01：`scripts/character/yangjian.gd` + `scenes/player/PlayerYangJian.tscn`
- Y02-Y04：`scripts/weapon/yangjian/*.gd`
- UI01：`scripts/ui/character_select_panel.gd` + `scenes/ui/CharacterSelectPanel.tscn`

### 黑名单（R002/R003 保护）
- character_base.gd / active_skill_character.gd / sun_wukong_v2.gd
- Player.tscn（修行者）/ PlayerSunWukong.tscn
- 所有 enemy / system / 武器（修行者+孙悟空）
- player.gd 除升级池/apply 外的逻辑
- docs / .claude / AGENTS.md / project.godot

---

## 6. 依赖图 + 执行顺序

```
NEZHA-PRE (HUD通用化)
  └─→ N01 → N02/N03/N04(并行) → N05 → 哪吒可玩
N01 完成后 → Y01 → Y02/Y03/Y04(并行) → Y05 → 杨戬可玩
NEZHA-PRE + N01 + Y01 → UI01 → 4 角色全可选
```

执行批次（主控规划）：
- 批 1：NEZHA-PRE + N01 + N02（最小可玩哪吒）
- 批 2：N03 + N04 + N05（哪吒完整）
- 批 3：Y01 + Y02 + Y03（杨戬 + 哮天犬）
- 批 4：Y04 + Y05（杨戬完整）
- 批 5：UI01（4 角色选择）

---

## 7. 风险点

- **R-HIGH HUD 字段名硬编码**：`hud.gd:300` 写死 `current_lingqi`，NEZHA-PRE 必须通用化（从 value_field 读），否则新角色能量条永远 0
- **R-HIGH player.gd 升级池武器节点名耦合**：N05/Y05 必须用 `if _character_base is Nezha/YangJian` 守门，不影响修行者/孙悟空
- **R-MED 哮天犬减速**：直接改 enemy.move_speed（duck typing）+ Timer 还原，不改 enemy.gd 基类
- **R-MED PlayerNezha.tscn 结构**：节点名必须匹配 player.gd @onready 路径（$HealthBar/Fill 等）
- **R-LOW 角色选择 4 按钮布局**：GridContainer 2×2 避免溢出

---

## 8. 验收标准

- 4 角色（修行者/孙悟空/哪吒/杨戬）都能从角色选择面板进入
- 哪吒：火尖枪自动攻击 + 受伤蓄三昧真火 + 满时下次攻击爆发
- 杨戬：三尖刀自动攻击 + 击杀/时间蓄天眼 + 哮天犬常驻咬击减速
- 哪吒/杨戬完整通关 3 关
- R002 修行者 + R003 孙悟空完全不受影响

---

## 9. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-26 | 1.0 | 哪吒+杨戬立项 — 6 决策 + 双角色 6 武器 + 12 任务 |
