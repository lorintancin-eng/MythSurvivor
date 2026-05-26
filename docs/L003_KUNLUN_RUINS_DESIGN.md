# L003 三·昆仑残境 — 关卡设计稿（v0.6 立项）

> **状态**：✅ 设计已定稿（用户 2026-05-26 拍板 6 个关键决策）
> **关联**：[06_LEVEL_DESIGN.md](06_LEVEL_DESIGN.md) §6.3 / [09_ROADMAP.md](09_ROADMAP.md) §3.6 / [L002_GHOST_MARKET_DESIGN.md](L002_GHOST_MARKET_DESIGN.md)
> **目标版本**：v0.6（继 v0.5 L002 完成后的下一个里程碑）
> **关联 ADR**：[ADR-0004 v0.5 关卡优先策略](decisions/0004-levels-before-characters.md)

---

## 1. 关键设计决策（6 项，已拍板）

| # | 决策 | 选择 | 理由 |
|---|---|---|---|
| D1 | 地形效果系统架构 | **Area2D 信号 + Player 统一 apply_terrain_effect** | 集中 buff 管理 / 避免 Area2D 感知 Player 内部 |
| D2 | 古阵效果种类 | **减速 + 闪烁** | 减速逼迫躲避 / 闪烁制造惊喜；不做加速（避免玩家主动找地形）|
| D3 | 浮空石奖励 | **固定 4 个 XP orb**（同镇妖碑）| 不接入材料系统，保留 `extra_drops` 字段供 v0.7+ 扩展 |
| D4 | 裂境山君技能 | **4 技能套餐 1+2+4+6**（阵法陷阱+灵脉震击+光柱阵+镇压）| 不依赖 G01 地形耦合 / 全部复用现有 burst+telegraph 框架 |
| D5 | 五行相克系统 | **v0.6 不启用**，延后 v0.7 | 五行影响所有现有武器+敌人（5+13 个），交叉影响面过大；L003 不依赖五行也能成立 |
| D6 | 通关 L003 后流程 | **加 Victory Screen 结算 UI**（"太上邀末煌" 面板）| 让玩家有"通关感"；循环模式留 v0.8+ |

---

## 2. 13 任务全表

> 比 L002 多 1 个 G13（Victory Screen 通关结算 UI）

### 阶段 0：基础设施（3 任务，**新机制**）

| ID | 任务 | 工作量 | 涉及文件 |
|---|---|---|---|
| **G01** | TerrainEffect 系统 | 大 | `scripts/system/terrain_effect.gd` + `scenes/system/TerrainEffect.tscn` + player.gd 加 `apply_terrain_effect(type, duration)` |
| **G02** | BreakableObject 系统 | 中 | `scripts/system/breakable_object.gd` + `scenes/system/BreakableObject.tscn` + 武器命中检测兼容（`hittable` group）|
| **G03** | L003 StageConfig 骨架 | 小 | `resources/stages/stage_03_kunlun.tres`（background_color + 占位 wave）|

### 阶段 1：L003 内容（9 任务）

| ID | 任务 | 工作量 | 涉及文件 |
|---|---|---|---|
| G04 | 山魈普通版 archetype | 小 | `resources/enemies/shanxiao_normal.tres`（复用 Enemy.tscn）|
| **G05** | 蛇妖（远程） | 中 | `scripts/enemy/serpent_spirit.gd`（继承 RangedEnemy）+ `scenes/enemy/SerpentSpirit.tscn` + `resources/enemies/serpent_spirit.tres` |
| G06 | 黑羽妖 archetype | 小 | `resources/enemies/dark_feather.tres`（WAVE_CHASE 模式）|
| G07 | 古阵守卫 archetype | 小 | `resources/enemies/array_guardian.tres`（高 HP 肉盾）|
| G08 | 古阵守卫精英 archetype | 小 | `resources/enemies/array_guardian_elite.tres`（is_elite + iron_bones）|
| **G09** | 裂境山君 Boss | 大 | `scripts/enemy/lieping_shanjun_boss.gd` + `scenes/enemy/LiepingShanjunBoss.tscn` |
| G10 | L003 5 wave pools | 小 | `resources/stages/wave_pools/stage_03_wave_0~4.tres` |
| G11 | L003 StageConfig 补完 | 小 | 串联 G09 boss_scene + G10 wave_pools |
| **G13** | Victory Screen 结算 UI | 中 | `scripts/ui/victory_panel.gd` + `scenes/ui/VictoryPanel.tscn` + StageDirector 通关分支 |
| G12 | L003 端到端 QA | 中 | 5 分钟完整对局 + Boss 验收 + Victory Screen 流程 |

---

## 3. 裂境山君 B201 详细设计

### 3.1 基础属性

| 字段 | 值 | 说明 |
|---|---|---|
| **stage** | L003 妖王（v0.6 收官）| Boss 类型 |
| **max_hp** | 420 | 高于鬼市判官 320（玩家通过 2 关已升满 Lv20）|
| **move_speed** | 50 | 慢移速，靠技能控场 + 阵地 |
| **damage**（接触）| 22 | 接触伤害 |
| **scale** | 2.0 | 最大（vs 鬼市判官 1.7 / 荒年兽 1.8）|
| **enrage_health_ratio** | 0.35 | 同 L002，35% 暴怒 |

### 3.2 4 技能详细数值

#### 技能 1：阵法陷阱（基础 AOE，cd 4.5s）
- Boss 在地面预设 **3-5 个蓝色圆形标记**（玩家附近 200px 范围内）
- 预警 **1.0s**
- 每个圆引爆：半径 **52px** / 伤害 **14**
- 复用 FamineBeastBoss burst_marker 逻辑
- 暴怒后 cd ×0.65 = 2.9s

#### 技能 2：灵脉震击（线形伤害，cd 6s）
- 向**玩家当前位置方向**发射**宽线形伤害带**
- 宽 **60px** / 长 **360px**
- 预警 **0.8s**（Line2D telegraph 显示）
- 引爆伤害 **20**（贯穿，全程伤害）
- 视觉：蓝白光效
- 暴怒后 cd ×0.65 = 3.9s

#### 技能 4：蓝色光柱阵（多点 AOE，cd 5s）
- 玩家**周围 80-160px** 随机 **4 点**同时降落光柱
- 预警 **0.6s**（蓝色圆圈）
- 每柱伤害 **10**（独立判定）
- 暴怒后 cd ×0.65 = 3.25s

#### 技能 6：镇压（全屏减速，cd 12s）
- 全屏发出**蓝色脉冲波纹**
- 玩家移速 **-40%** 持续 **3s**
- 调用 player.gd 的 `apply_terrain_effect(SLOW, 3.0)`（与 G01 共用接口）
- 注意：与七十二变 / 筋斗云等孙悟空 buff 叠加规则 — 取**最低**当前移速倍率
- 暴怒后 cd ×0.65 = 7.8s

### 3.3 暴怒机制（35% 血量）

- 所有技能冷却 ×0.65
- 移速 ×1.3 = 65（缓慢但更快）
- 接触伤害 ×1.3 = 29
- 视觉：**蓝紫光环**（与 L001 红色、L002 紫色区分）
- 不召唤额外古阵守卫（保持 4 技能纯净，避免 boss 战混乱）

### 3.4 与 L001/L002 Boss 的差异化

| 维度 | 荒年兽 B001 | 鬼市判官 B101 | **裂境山君 B201** |
|---|---|---|---|
| 玩法核心 | 冲撞 + 爆发 | 召唤 + 阵地 | **阵法 + 多点 AOE** |
| 体型 scale | 1.8 | 1.7 | **2.0**（最大）|
| HP | 260 | 320 | **420** |
| 移速 | 70 | 60 | **50**（最慢）|
| 远程能力 | 无 | 判决鸣鞭 | **灵脉震击**（线形）|
| 控场技能 | 无 | 阵法封锁 + 传送 | **阵法陷阱 + 镇压**（全屏减速）|
| 召唤上限 | 6 | 8 | **0**（无召唤，技能纯净）|
| Boss 个性 | "野蛮冲撞" | "权威阵法" | **"上古阵纹"** |
| 暴怒色 | 红 | 紫 | **蓝紫** |

---

## 4. 5 怪物详细设计

### 4.1 山魈普通版（G04）

```yaml
hp: 52
move_speed: 78
contact_damage: 11
damage_interval: 0.85
xp_value: 10
behavior: CHASE 直线追击
visual:
  body_color: Color(0.55, 0.40, 0.65, 1)  # 棕紫
  scale: 1.1
  shape: 6 边形（山魈剪影）
```

### 4.2 蛇妖（G05，远程，继承 RangedEnemy）

```yaml
hp: 38
move_speed: 64
contact_damage: 9
ranged:
  attack_range: 220
  preferred_distance: 160
  projectile_damage: 7
  projectile_speed: 240
  fire_interval: 2.8
  projectile_color: Color(0.4, 0.85, 0.6, 0.9)  # 翠绿
  burst_count: 1-3  # 随机 1-3 连弹
xp_value: 14
visual:
  body_color: Color(0.3, 0.6, 0.45, 1)  # 蛇身绿
  shape: 长椭圆（蛇形）
```

### 4.3 黑羽妖（G06，飘浮）

```yaml
hp: 28
move_speed: 108
contact_damage: 8
damage_interval: 0.75
xp_value: 9
behavior: WAVE_CHASE（波动追击）
  wave_amplitude: 0.70
  wave_frequency: 1.25
visual:
  body_color: Color(0.15, 0.12, 0.20, 0.9)  # 深蓝黑
  scale: 0.85
  shape: 菱形带羽
```

### 4.4 古阵守卫（G07，肉盾）

```yaml
hp: 120
move_speed: 46
contact_damage: 14
damage_interval: 1.1
xp_value: 18
behavior: CHASE 直线（无波动）
visual:
  body_color: Color(0.30, 0.45, 0.55, 1)  # 深灰蓝
  scale: 1.5
  shape: 八边形（甲冑）
  collision_radius: 18
```

### 4.5 古阵守卫精英（G08）

```yaml
# 基于 G07 + 精英加成
hp: 174  # 120 × 1.45（iron_bones）
move_speed: 48  # 46 × 1.05
contact_damage: 17  # 14 × 1.2
damage_interval: 1.1
xp_value: 32
is_elite: true
affixes: ["iron_bones"]
# 复用 G07 scene + Enemy.tscn
visual:
  body_color: Color(0.50, 0.65, 0.85, 1)  # 亮蓝
  glow: true
```

---

## 5. 新机制设计

### 5.1 G01 TerrainEffect 系统

**架构**（决策 D1）：
- Area2D 信号 `body_entered(player)` / `body_exited(player)`
- Player 统一接口：
```gdscript
func apply_terrain_effect(effect_type: int, duration: float) -> void
func remove_terrain_effect(effect_type: int) -> void
```
- Player 内部维护 `_active_terrain_effects: Dictionary` 管理叠加 / 移除

**效果种类**（决策 D2）：
- `TerrainEffect.Type.SLOW` — 玩家移速 ×0.65，持续 buff 直到离开 Area2D
- `TerrainEffect.Type.BLINK` — 玩家进入瞬间随机瞬移 60-100px（一次性触发，进入 cooldown 1.0s 防连击）

**视觉**：
- SLOW 区域：地面深蓝紫色半透明圆（_draw 绘制）
- BLINK 区域：地面闪烁亮蓝色（modulate 周期变化）

### 5.2 G02 BreakableObject 系统

**架构**：
- Node2D + Area2D（被武器击中检测）
- `take_damage(amount)` 接口（属于 group `hittable`）
- HP 30（约 3-4 次普通攻击）
- 死亡掉落：固定 4 个 XP orb（决策 D3，复用镇妖碑奖励 orb scene）
- 预留 `extra_drops: Array[PackedScene]` 字段供 v0.7+ 材料系统扩展

**武器命中适配**：
- 所有武器的 hit area 需要扫描 `hittable` group（而不仅是 `enemies`）
- 影响武器：talisman / flying_sword / thunder_law / bagua_array / explosive_talisman / mountain_seal（修行者 6 武器）+ JinguBangV2 + 4 孙悟空主动技能
- **R002 / R003 保护**：现有武器逻辑只追加 group 检测，不改伤害计算

**视觉**：
- 静态浮空石 Polygon2D（灰蓝色，半透明，scale 1.2-1.5）
- 被击破：分裂为 3 个小石片（粒子或 Tween 缩放消失）

### 5.3 关卡视觉差异化

继承 L002 主题色架构：
- L001 暗绿黑 `Color(0.08, 0.10, 0.06, 1)`
- L002 紫黑 `Color(0.10, 0.06, 0.15, 1)`
- **L003 蓝黑 `Color(0.04, 0.08, 0.14, 1)`**（在 stage_03_kunlun.tres 中 background_color 字段设置）

---

## 6. G13 Victory Screen 详细设计

### 6.1 触发条件
- StageDirector `stage_cleared` 信号（裂境山君死亡）
- 检查 `StageRegistry.get_next_stage_id(current_stage_id) == ""` — 即"通关结束"
- 显示 Victory Panel（区别于 GameOverPanel 的"道消身陨"）

### 6.2 UI 设计

```
┌────────────────────────────────────┐
│       太上邀末煌（通关）           │
├────────────────────────────────────┤
│                                    │
│  存活时长: 14:32                   │
│  击败妖物: 287                     │
│  最高境界: Lv24                    │
│  通关角色: 齐天大圣                │
│                                    │
│   [再入劫境]    [回到主菜单]       │
└────────────────────────────────────┘
```

### 6.3 实现要点
- 复用 GameOverPanel.tscn 结构（CanvasLayer 80% 透明背景 + Center Panel）
- 文字与 GameOverPanel 区分：
  - GameOverPanel: "道消身陨" + "再入劫境" + 失败基调（灰色）
  - VictoryPanel: "太上邀末煌" + "再入劫境" / "回到主菜单" + 胜利基调（金蓝色）
- 数据来源：
  - 存活时长 = StageDirector elapsed_time 累计（跨关）→ 需要 GameState 跟踪
  - 击败妖物 = EnemySpawner.defeated_enemy_count 跨关累计
  - 最高境界 = player.gd current level
  - 通关角色 = character_base.display_name

### 6.4 跨关数据跟踪（GameState 扩展）

GameState（隐含的全局状态）需要在 F02 跨关延续基础上增加：
- `_total_elapsed_time: float` — 跨 3 关累计时长
- `_total_defeated_enemies: int` — 跨 3 关累计击杀数
- `_highest_level_reached: int` — 整局达到的最高境界

实现位置：在 StageDirector `load_stage_config` 中累计上一关数据，新关重置 elapsed_time/defeated_count 但保留 total 字段。

---

## 7. 与现有系统的兼容性

### 7.1 R001 L001 保护
- StageDirector 无修改（沿用 v0.5 数据驱动）
- L001 stage_01_huangshan.tres 不动
- 修行者武器 / 孙悟空所有功能不受影响

### 7.2 R002 修行者保护
- L003 5 怪物全部使用现有 Enemy / RangedEnemy 框架
- 修行者武器在 L003 全部正常工作
- 修行者通过 L001+L002+L003 完整通关 → Victory Screen

### 7.3 R003 孙悟空保护
- L003 适配孙悟空所有技能
- 火眼金睛对裂境山君生效（+20% 起步，最高 +55%）
- 镇压全屏减速对孙悟空 buff 兼容（取最低倍率）

### 7.4 镇妖碑系统
- L003 沿用镇妖碑机制（与 L001/L002 相同）
- 可以与 G02 BreakableObject 同框（两套独立系统）

---

## 8. 验收标准

### 8.1 通过条件（v0.6 release）
- ✅ L001 → L002 → L003 完整链条无中断
- ✅ L003 5 种新敌人正常生成 / 行为正确
- ✅ 裂境山君 4 技能各能触发（阵法陷阱 / 灵脉震击 / 光柱阵 / 镇压）
- ✅ 暴怒（35% HP）正确触发 + 蓝紫光环可见
- ✅ TerrainEffect 减速 / 闪烁正常工作
- ✅ BreakableObject 可被武器击破 + 掉 4 个 XP orb
- ✅ 裂境山君死后弹出 Victory Screen
- ✅ Victory Screen 数据正确（时长 / 击杀 / 境界 / 角色）
- ✅ 修行者 + 孙悟空两个角色均能完整通关 3 关

### 8.2 阻塞级 FAIL
- 🔴 Boss 死后未触发 Victory Screen
- 🔴 TerrainEffect 移速修改后玩家不能恢复（buff 泄漏到下一关）
- 🔴 武器无法击破 BreakableObject
- 🔴 RangedEnemy 在 L003 蛇妖中行为异常
- 🔴 镇压全屏减速与孙悟空 buff 冲突，导致永久减速

---

## 9. 实施顺序

### 推荐启动序列（每个任务严格 5 步流程）

```
Phase 0 基础设施 (3):  G01 → G02 → G03         预估 2.5 个 session
Phase 1 资源/敌人 (5): G04+G06+G07+G08 并行 → G05  预估 1.5 个 session
Phase 2 Boss + UI (2): G09 → G13                预估 2 个 session
Phase 3 配置 + QA (3): G10 → G11 → G12          预估 1 个 session
```

**总预估**：**7 个 session** 完成 v0.6 L003 完整发布

---

## 10. 风险点

- **R01 (高)**：G01 TerrainEffect 修改 Player 核心字段（_active_terrain_effects），需完整回归 L001 / L002
- **R02 (中)**：G02 BreakableObject 需要修改所有武器的 hit 检测（追加 `hittable` group），可能漏改某个武器
- **R03 (中)**：G05 蛇妖依赖 v0.5 RangedEnemy（已合 main 前提）
- **R04 (中)**：G09 Boss 复杂度 — 4 技能 + 暴怒，估算 400-500 行
- **R05 (低)**：Victory Screen 需要新 GameState 跟踪跨关数据，可能与 F02 状态延续冲突
- **R06 (低)**：镇压技能调用 player.apply_terrain_effect 与孙悟空七十二变 buff 叠加规则需 QA 验证

---

## 11. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-26 | 1.0 | L003 立项 — 6 决策定稿 + 13 任务 + Boss 4 技能详细数值 |
