class_name ActiveSkillCharacter
extends CharacterBase

## 主动技能角色基类（v0.4 引入）
##
## 管理 4 个主动技能槽的 cooldown 状态。
## 子类（如 SunWukongV2）通过 _register_skill() 注册槽位 + max_cd，
## 通过 override _on_cast_skill() 实现具体技能逻辑。
##
## ⚠️ ActiveSkillCharacter 是项目内**唯一**面向"主动按键释放"角色的基类。
## 其他全自动角色（修行者 / 哪吒 / 杨戬 / 女娲 / 盘古）不应继承此类。
## 详见 docs/decisions/0003-sun-wukong-active-skills.md

# 4 个技能槽中任一槽的 cooldown / unlocked 状态变化时 emit
# 参数：slot (0-3), remaining (秒), max_cd (秒), unlocked
signal skill_cooldown_changed(slot: int, remaining: float, max_cd: float, unlocked: bool)

# ─────────────────────────────────────────────
# 4 槽状态数组（固定长度 4）
# ─────────────────────────────────────────────

var _skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _skill_max_cds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _skill_unlocked: Array[bool] = [false, false, false, false]
var _skill_names: Array[String] = ["", "", "", ""]


# 每帧推进 4 槽 cooldown
func _process(delta: float) -> void:
	for slot in range(4):
		if _skill_cooldowns[slot] > 0.0:
			_skill_cooldowns[slot] = maxf(_skill_cooldowns[slot] - delta, 0.0)
			# 通知 HUD（每帧都 emit 让倒计时显示流畅）
			skill_cooldown_changed.emit(
				slot,
				_skill_cooldowns[slot],
				_skill_max_cds[slot],
				_skill_unlocked[slot]
			)


# 注册一个技能槽（子类调用，通常在 _init 或 _ready）
# slot: 0-3 对应键位 1-4
# skill_name: 技能名（如"毫毛分身"），W213 角色选择 UI 可显示
# max_cd: 该技能 cooldown 秒数
func _register_skill(slot: int, skill_name: String, max_cd: float) -> void:
	if slot < 0 or slot > 3:
		push_warning("ActiveSkillCharacter._register_skill: invalid slot %d" % slot)
		return
	_skill_names[slot] = skill_name
	_skill_max_cds[slot] = max_cd
	_skill_unlocked[slot] = true
	_skill_cooldowns[slot] = 0.0
	# 主动 emit 一次，让 HUD（即使已 _ready）能收到初始状态
	skill_cooldown_changed.emit(slot, 0.0, max_cd, true)


# 玩家按 1/2/3/4 键时由 player.gd 转发到这里（W212 接入）
# 返回 true 表示成功释放（cooldown 启动）
func cast_skill(slot: int) -> bool:
	if slot < 0 or slot > 3:
		return false
	if not _skill_unlocked[slot]:
		return false
	if _skill_cooldowns[slot] > 0.0:
		return false
	# 调用子类 override
	var success: bool = _on_cast_skill(slot)
	if success:
		_skill_cooldowns[slot] = _skill_max_cds[slot]
		skill_cooldown_changed.emit(slot, _skill_cooldowns[slot], _skill_max_cds[slot], true)
	return success


# 子类 override 实现具体技能逻辑
# 返回 true 表示技能成功释放（基类会启动 cooldown），false 表示释放失败（不消耗 cooldown）
func _on_cast_skill(_slot: int) -> bool:
	return false


# 查询接口（HUD 或调试用）
func get_skill_cooldown(slot: int) -> float:
	if slot < 0 or slot > 3:
		return 0.0
	return _skill_cooldowns[slot]


func get_skill_max_cd(slot: int) -> float:
	if slot < 0 or slot > 3:
		return 0.0
	return _skill_max_cds[slot]


func is_skill_unlocked(slot: int) -> bool:
	if slot < 0 or slot > 3:
		return false
	return _skill_unlocked[slot]


# 火眼金睛接口：返回对该 target 的伤害倍率（W206 预留）
# 默认返回 1.0（无加成）；SunWukong v2 子类 override 实现"对精英/Boss +20%"
func get_damage_modifier(_target: Node) -> float:
	return 1.0
