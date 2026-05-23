class_name SunWukong
extends CharacterBase

## 孙悟空角色（Sun Wukong Character）
##
## 齐天大圣，自称"弼马温"。混战之王，越乱越强。
## 击杀敌人积累灵气，灵气满 30 自动触发"七十二变"。
##
## v0.3 T202：骨架占位（字段赋值 + virtual override 空体）。
## 完整功能由后续任务实施：
## - 七十二变机制 → T203
## - 三件武器（金箍棒 / 金箍棒·变长 / 毫毛分身） → T204-T206
## - 升级池过滤接入 → T207
## - 角色选择 UI 与场景 → T209
##
## 详细设计：docs/02_CHARACTER_DESIGN.md §4.2


func _init() -> void:
	character_id = "sun_wukong"
	display_name = "弼马温"
	max_health = 100.0
	move_speed = 230.0
	pickup_radius = 60.0
	initial_weapon_id = "wukong_jingu_bang"
	element = "metal"
	unlock_condition = {}
	energy_bar_config = {
		"max_value": 30.0,
		"fill_color": Color(0.96, 0.92, 0.78),
		"label": "灵气",
		"auto_trigger": true,
	}


# ─────────────────────────────────────────────
# 灵气状态（运行时）
# ─────────────────────────────────────────────

## 当前灵气累积值，由 _on_kill 充能
var current_lingqi: float = 0.0

## 灵气是否已用于触发七十二变（防止重复触发）
var _is_72_transform_active: bool = false


## 击杀敌人时充能灵气。
## 普通怪 +1 灵气，精英 +5 灵气，Boss 不触发。
## 参数类型必须是 Node（基类约定，避免对 Enemy 的循环依赖）。
func _on_kill(enemy: Node) -> void:
	if _is_72_transform_active:
		return
	if enemy == null:
		return
	# Boss 不触发灵气充能
	if enemy.is_in_group("bosses"):
		return
	# 精英 +5，普通 +1
	var gain: float = 5.0 if enemy.get("is_elite") == true else 1.0
	current_lingqi = minf(current_lingqi + gain, energy_bar_config.get("max_value", 30.0))
	if current_lingqi >= energy_bar_config.get("max_value", 30.0):
		_on_energy_full()


## 灵气满时自动触发七十二变。
## 3 秒内伤害+50% / 移速+30% / 无敌（敌人无法瞄准）。
## 触发时 emit energy_full_triggered signal 供 HUD 监听；触发后灵气清零。
func _on_energy_full() -> void:
	if _is_72_transform_active:
		return
	_is_72_transform_active = true
	energy_full_triggered.emit()
	# 影响 player：3 秒无敌 + 移速 +30%
	if owner != null:
		if owner.has_method("set_invincible"):
			owner.set_invincible(true)
		if owner.has_method("set_speed_multiplier"):
			owner.set_speed_multiplier(1.3)
		if owner.has_method("set_damage_multiplier"):
			owner.set_damage_multiplier(1.5)
	# 3 秒后恢复
	get_tree().create_timer(3.0).timeout.connect(_on_72_transform_ended)


## 孙悟空专属升级池 ID 列表（供 T207 升级池过滤使用）。
## 修复 BUG-T207-01：返回真实强化 ID 以匹配 player.gd 升级池条目。
func _get_allowed_upgrade_ids() -> Array[String]:
	return [
		"wukong_jingu_bang_damage",
		"wukong_jingu_bang_radius",
		"wukong_jingu_bang_extend_damage",
		"wukong_jingu_bang_extend_cooldown",
		"wukong_hair_clone_damage",
		"wukong_hair_clone_count",
	]


func _on_72_transform_ended() -> void:
	_is_72_transform_active = false
	current_lingqi = 0.0
	if owner != null:
		if owner.has_method("set_invincible"):
			owner.set_invincible(false)
		if owner.has_method("set_speed_multiplier"):
			owner.set_speed_multiplier(1.0)
		if owner.has_method("set_damage_multiplier"):
			owner.set_damage_multiplier(1.0)
