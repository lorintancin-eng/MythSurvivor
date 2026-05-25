# L002 幽都鬼市 — 关卡设计稿（v0.5 立项）

> **状态**：✅ 设计已定稿（用户 2026-05-25 拍板 7 个关键决策）
> **关联**：[06_LEVEL_DESIGN.md](06_LEVEL_DESIGN.md) §6.2 / [09_ROADMAP.md](09_ROADMAP.md)
> **目标版本**：v0.5（暂停 v0.5 哪吒/杨戬规划，先做关卡）
> **关联 ADR**：待生成 ADR-0004（v0.5 关卡优先策略调整）

---

## 1. 关键设计决策（7 项，已拍板）

| # | 决策 | 选择 | 理由 |
|---|---|---|---|
| 1 | 关卡解锁机制 | **v0.4 全解锁** | 跳过 A05 存档解锁，UNLOCK_ALL=true 常量控制。减少范围 |
| 2 | 主菜单顺序 | 🔴 **生存模式 — 无选关 UI** | **Boss 死亡后自动推进 L002**。Vampire Survivors 风格 |
| 3 | StageConfig 存放 | **resources/stages/ 独立 .tres** | 多关扩展最干净，L001 同步从硬编码提取 |
| 4 | 远程攻击系统 | **RangedEnemy extends Enemy 子类** | 零侵入现有 5 怪 + Boss，无需 R002 全量回归 |
| 5 | 鬼市判官技能 | **4 技能套餐**（召唤+阵法+鸣鞭+传送）| 与荒年兽对齐 4 技能位，需 C01 远程系统 |
| 6 | Buff/Debuff 框架 | **仅光环硬编码** | 妖僧残念单点效果，通用框架延到 v0.6 |
| 7 | 关卡切换方式 | **不切场景 + 淡入淡出 + StageConfig 热切** | 玩家状态全保留，最顺滑 |

---

## 2. 14 任务全表

### 阶段 0：架构基础（4 任务）

| ID | 任务 | 工作量 | 涉及文件 |
|---|---|---|---|
| **A01** | StageConfig Resource 类 | 中 | `scripts/system/stage_config.gd`（新建）|
| **A02** | StageDirector 数据驱动化 | 中 | `scripts/system/stage_director.gd`（重构）+ `resources/stages/stage_01_huangshan.tres`（新建）|
| **A03** | BossConfig Resource 类 | 小 | `scripts/system/boss_config.gd`（新建）|
| **A04** | StageRegistry 关卡注册表 | 小 | `scripts/system/stage_registry.gd`（新建静态类，无 Autoload）|

### 阶段 1：关卡过渡机制（2 任务，决策 #7 新增）

| ID | 任务 | 工作量 | 涉及文件 |
|---|---|---|---|
| **F01** | StageTransition 关卡过渡 | 中 | `scripts/system/stage_transition.gd`（新建）+ `scenes/ui/StageTransition.tscn`（新建）|
| **F02** | 跨关玩家状态延续 | 中 | `scripts/system/game_state.gd`（新建）+ `scripts/player/player.gd`（minor 改）|

### 阶段 2：远程攻击基础设施（1 任务）

| ID | 任务 | 工作量 | 涉及文件 |
|---|---|---|---|
| **C01** | RangedEnemy 子类 + 投射物 | 大 | `scripts/enemy/ranged_enemy.gd`（新建继承 Enemy）+ `scripts/enemy/enemy_projectile.gd`（新建）+ `scenes/enemy/RangedEnemy.tscn`（继承 Enemy.tscn）+ `scenes/enemy/EnemyProjectile.tscn`（新建）|

### 阶段 3：L002 内容（7 任务）

| ID | 任务 | 工作量 | 涉及文件 |
|---|---|---|---|
| **D01** | L002 StageConfig 资源 | 小 | `resources/stages/stage_02_ghost_market.tres`（新建）|
| **D02** | 灯笼鬼（自爆） | 中 | `resources/enemies/lantern_ghost.tres` + `scripts/enemy/lantern_ghost.gd` |
| **D03** | 鬼差（远程） | 中 | `resources/enemies/ghost_officer.tres` + `scripts/enemy/ghost_officer.gd`（继承 RangedEnemy）|
| **D04** | 怨婴（群体） | 小 | `resources/enemies/grieving_infant.tres`（复用 Enemy）|
| **D05** | 妖僧残念（光环） | 大 | `resources/enemies/demon_monk.tres` + `scripts/enemy/demon_monk.gd`（含光环逻辑）|
| **D06** | 镜妖精英 | 小 | `resources/enemies/mirror_demon_elite.tres` |
| **D07** | 鬼市判官 Boss 4 技能 | 大 | `scripts/enemy/ghost_judge_boss.gd` + `scenes/enemy/GhostJudgeBoss.tscn` |

### 注：D08 视觉装饰

L002 视觉差异化（紫蓝色调 + 灯笼粒子）通过 **StageTransition 的"主题色"机制**（F01）实现，不单独立任务。如果需要装饰物件（破灯笼/阴摊），归入 v0.6 美术升级。

---

## 3. 鬼市判官 Boss 详细设计

### 3.1 基础属性

| 字段 | 值 | 说明 |
|---|---|---|
| **stage** | L002 妖王 | Boss 类型 |
| **max_hp** | 320 | 略低于荒年兽 360（玩家此时已升级）|
| **move_speed** | 60 | 慢移速，靠技能控场 |
| **damage**（接触）| 18 | 接触伤害 |
| **scale** | 1.7 | 略小于荒年兽（1.8）|
| **enrage_health_ratio** | 0.35 | 35% 血量暴怒（vs 荒年兽 30%）|

### 3.2 4 技能详细数值

#### 技能 1：召唤鬼差（基础技能，cd 6s）
- 一次召唤 **2-3 只鬼差**（D03 远程敌人）
- 场上召唤物上限 **8** 只（vs 荒年兽 6）
- 召唤位置：判官周围 80px 半径圆周
- 暴怒后冷却 ×0.65 = 3.9s

#### 技能 2：阵法封锁（核心 AOE，cd 5s）
- 玩家**当前位置**生成阵法红圈
- 预警 **1.2s**（vs 荒年兽 1.05s — 更长，更可躲）
- 半径 **80px**（vs 荒年兽 burst 58px — 更大）
- 引爆伤害 **22**（vs 荒年兽 burst 18）
- 暴怒后冷却 ×0.65 = 3.25s

#### 技能 3：判决鸣鞭（远程投射，cd 4.5s，**依赖 C01**）
- 向玩家**连续射 3 发**判官印投射物
- 间隔 0.3s
- 单发伤害 **12**
- 飞行速度 280 px/s
- 玩家可侧移规避
- 暴怒后冷却 ×0.65 = 2.9s

#### 技能 4：传送（阵地控制，cd 8s）
- 判官**消失 0.5s**（无敌）→ 出现在距玩家 350-400px 的随机方向
- 出现瞬间触发一次小范围爆裂（半径 60px / 伤害 10）
- 暴怒后冷却 ×0.65 = 5.2s

### 3.3 暴怒机制（35% 血量）

- 所有技能冷却 ×0.65
- 移速 ×1.3 = 78（vs 荒年兽 ×1.35 = 95）
- 接触伤害 +30% = 23
- 视觉：紫色光环（vs 荒年兽红色）

### 3.4 与荒年兽的差异化

| 维度 | 荒年兽 B001 | 鬼市判官 B101 |
|---|---|---|
| 玩法核心 | 冲撞 + 爆发 | 召唤 + 阵地 |
| 移速 | 快（70）| 慢（60）|
| 远程能力 | 无 | **判决鸣鞭**（依赖 C01）|
| 控场技能 | 无 | **传送 + 阵法封锁**（双控场）|
| 召唤上限 | 6 | 8 |
| Boss 个性 | "野蛮冲撞" | "权威阵法" |

---

## 4. L002 5 怪物详细设计

### 4.1 灯笼鬼（D02，自爆）

```yaml
hp: 18
move_speed: 90
contact_damage: 0  # 不接触伤害，靠自爆
xp_value: 2.5
behavior:
  - 持续追玩家
  - 距离 < 50px 触发自爆
  - 自爆: 半径 70px / 伤害 25 / 红色预警 0.5s
  - 自爆后 die（不算 contact 计数）
visual:
  body_color: Color(1.0, 0.5, 0.15, 1)  # 橘红
  shape: 圆形 + 顶部小尖（灯笼造型）
```

### 4.2 鬼差（D03，远程，**继承 RangedEnemy**）

```yaml
hp: 35
move_speed: 70
contact_damage: 8
xp_value: 4.0
ranged:
  attack_range: 250         # 在这个距离内攻击
  preferred_distance: 200    # 保持距离
  projectile_damage: 8
  projectile_speed: 220
  fire_interval: 1.8         # 每 1.8s 射一发
  projectile_color: Color(0.3, 0.8, 0.9, 0.9)  # 青蓝
behavior:
  - 距离 > preferred_distance: 接近
  - 距离 < preferred_distance: 后退
  - 距离 in [preferred-30, preferred+30]: 站定射击
visual:
  body_color: Color(0.45, 0.35, 0.55, 1)  # 紫灰
  shape: 6 边形（差役站姿）
```

### 4.3 怨婴（D04，群体）

```yaml
hp: 8
move_speed: 130
contact_damage: 4
xp_value: 1.5
group_spawn: 4-6           # StageDirector wave 配置批量
visual:
  body_color: Color(0.95, 0.85, 0.7, 0.8)  # 浅黄半透明
  scale: 0.6                # 小体型
  shape: 圆形
```

### 4.4 妖僧残念（D05，光环 Buff）

```yaml
hp: 50
move_speed: 65
contact_damage: 12
xp_value: 5.0
aura:
  radius: 120
  effect: 周围敌人移速 +25%
  visual: 紫色半透明圆圈（_draw 绘制）
behavior:
  - 慢速追击玩家
  - 优先保持在敌人群中央（给最多 buff）
visual:
  body_color: Color(0.6, 0.3, 0.7, 1)  # 紫红
  shape: 8 边形 + 内圈（僧人法相）
```

### 4.5 镜妖精英（D06）

```yaml
# 基础 = 狐妖 / 山魈精英变体
hp: 90 (精英常规)
move_speed: 110
contact_damage: 18
xp_value: 8.0
is_elite: true              # 复用 Enemy is_elite 字段
visual:
  body_color: Color(0.7, 0.8, 0.95, 0.85)  # 镜面青
  shape: 镜形菱形
  glow: true                # 精英标志
```

---

## 5. F01 StageTransition 详细设计

### 5.1 触发条件
- StageDirector 检测到 Boss 死亡（`_on_boss_died` signal）
- 等待 1.5s（让玩家看到通关 UI）
- 调用 `StageTransition.start_transition(next_stage_id)`

### 5.2 过渡动画时序

```
T=0.0s  Boss 死亡，"封印完成"通关 UI 弹出
T=1.5s  StageTransition 启动 → CanvasLayer 黑屏淡入（0.8s alpha 0→1）
T=2.3s  全屏黑色 + 显示"幽都鬼市" 大字（2s）
T=4.3s  执行 StageConfig 切换:
        - 清空所有敌人 / 经验球 / 镇妖碑
        - StageDirector.load_config(next_config)
        - 重置 elapsed_time = 0
        - 主题色调整（背景 ColorRect 颜色）
T=5.3s  黑屏淡出（0.8s alpha 1→0）
T=6.1s  L002 开始，玩家可操作
```

### 5.3 主题色变化

| 关卡 | 背景色 | UI 强调色 |
|---|---|---|
| L001 荒山古道 | `Color(0.08, 0.10, 0.06, 1)` 暗绿黑 | 金色 #d4af37 |
| L002 幽都鬼市 | `Color(0.10, 0.06, 0.15, 1)` 紫黑 | 青蓝 #4cb5d9 |
| L003 昆仑残境 | `Color(0.04, 0.08, 0.14, 1)` 蓝黑 | 玉绿 #6ed4a4 |

### 5.4 玩家状态保留（F02 配合）

切换时**保留**：
- ✅ HP / max_hp
- ✅ 等级 / 经验
- ✅ 已解锁武器 / 武器等级
- ✅ 升级 bonus（移速 / 拾取范围 / xp_gain）
- ✅ 孙悟空：4 技能解锁状态 + 等级 + 火眼金睛 stacks + 各 bonus 字段

切换时**重置**：
- 🔄 elapsed_time（关卡内时间）
- 🔄 镇妖数（按关计）
- 🔄 当前关卡内技能 cooldown（让玩家进新关时所有 cd 重置）

---

## 6. 与 v0.2 L001 的兼容性

### 6.1 R002 修行者保护
- L002 完全适配修行者（修行者所有武器在 L002 仍工作）
- 修行者通用升级在 L002 持续生效（max_hp 等延续）

### 6.2 R003 孙悟空保护
- L002 适配孙悟空（金箍棒 / 4 技能 / 火眼金睛全部延续）
- 已解锁的主动技能在 L002 保留，cd 重置
- 火眼金睛 stacks 跨关保留（最多 7 层）
- 鬼市判官属于 boss group → 火眼金睛对其生效（+20% 起步）

### 6.3 镇妖碑系统
- L002 沿用镇妖碑机制（与 L001 相同）
- 镇妖碑生成位置参数从 StageConfig 读取（决策 #3）

---

## 7. 验收标准

### 7.1 通过条件（合并 v0.5 release）
- ✅ L001 行为与 v0.4 完全一致（架构重构不破坏）
- ✅ L001 妖兽兽王死亡后 → 黑屏过渡 → L002 开始（生存模式核心）
- ✅ L002 5 种新敌人正常生成 / 行为正确
- ✅ 鬼市判官 4 技能各能触发
- ✅ 鬼市判官死亡后 → 通关结算（v0.5 暂无 L003，可显示"暂未开放"）
- ✅ 玩家跨关状态完整保留（HP / 等级 / 武器 / 升级 bonus）
- ✅ 修行者 + 孙悟空两个角色均能跨关
- ✅ 修行者 R002 + 孙悟空所有升级在 L002 仍正常工作

### 7.2 阻塞级 FAIL
- 🔴 Boss 死后未触发过渡（卡死）
- 🔴 过渡后 L001 配置仍在用（StageConfig 未热切）
- 🔴 玩家状态丢失（跨关后回到 Lv1）
- 🔴 RangedEnemy 影响现有敌人（R002 破坏）
- 🔴 鬼市判官某个技能完全不触发

---

## 8. 实施顺序

### 推荐启动顺序（每个任务严格 5 步流程）

```
Phase 0 架构: A01 → A02 → A03 → A04        预估 2 个 session
Phase 1 过渡: F01 → F02                    预估 1.5 个 session
Phase 2 基础: C01                          预估 1 个 session
Phase 3 内容: D01 + (D02/D04/D06 并行) + D03 + D05 + D07  预估 3-4 个 session
```

**总预估**：**7-8 个 session** 完成 v0.5 L002 完整发布

---

## 9. 风险点（pm-planner 已识别）

- **R01 (高)**：A02 重构影响 L001 — 需保留 fallback + 完整回归
- **R02 (高)**：C01 子类需场景继承 Enemy.tscn 不重建节点树
- **R03 (中)**：F01 过渡时机的信号链复杂（Boss 死信号 + 1.5s 延迟 + 淡入）
- **R04 (中)**：D07 鬼市判官复杂度可能超 500 行，技能数值需多轮调优
- **R05 (低)**：StageRegistry 不用 Autoload（静态类），避免 project.godot 改动

---

## 10. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-25 | 1.0 | L002 立项 — 7 决策定稿 + 14 任务 + Boss 4 技能详细数值 |
