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


## 击杀敌人时充能灵气。
## TODO T203: 普通怪 +1 灵气，精英 +5 灵气，Boss 不触发。
## 参数类型必须是 Node（基类约定，避免对 Enemy 的循环依赖）。
func _on_kill(_enemy: Node) -> void:
	pass


## 灵气满时自动触发七十二变。
## TODO T203: 3 秒内伤害+50% / 移速+30% / 无敌（敌人无法瞄准）。
## 触发时玩家剪影变小猴 + 青烟环绕；触发后灵气清零。
## 同时 emit energy_full_triggered signal 供 HUD 监听（R008 follow-up）。
func _on_energy_full() -> void:
	pass


## 孙悟空专属升级池 ID 列表（供 T207 升级池过滤使用）。
## TODO T204-T206 实施后，可能需要补武器强化项 ID（如 "wukong_jingu_bang_damage"）。
func _get_allowed_upgrade_ids() -> Array[String]:
	return [
		"wukong_jingu_bang",
		"wukong_jingu_bang_extend",
		"wukong_hair_clone",
	]
