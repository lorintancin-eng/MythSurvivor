class_name SunWukongV2
extends ActiveSkillCharacter

## SunWukongV2 — 齐天大圣 v0.4 重做版
##
## 项目内**唯一**主动技能角色（详见 ADR-0003）
##   - 主武器：金箍棒（自动扇形攻击，挂在 PlayerSunWukong.tscn 的 JinguBangV2 节点）
##   - 4 主动技能（按 1/2/3/4 释放，开局未解锁，靠 Lv5/10/15/20 选择）：
##     · 槽 0 毫毛分身 (cd 12s)
##     · 槽 1 筋斗云   (cd 8s)
##     · 槽 2 七十二变 (cd 25s)
##     · 槽 3 定身术   (cd 15s)
##   - 被动：火眼金睛（对精英/Boss +20% 伤害，由 get_damage_modifier 实现）
##
## 场景树：作为 PlayerSunWukong.tscn 的 CharacterBase 节点挂载
## 4 技能节点是 Player 的兄弟节点，通过 ../节点名 引用


# ─────────────────────────────────────────────
# 技能节点引用（兄弟节点，用 get_node_or_null 防御单测加载场景）
# ─────────────────────────────────────────────

@onready var _hair_clone: Node2D = get_node_or_null("../HairCloneV2")
@onready var _cloud_step: Node2D = get_node_or_null("../CloudStep")
@onready var _transform: Node2D = get_node_or_null("../Transform72")
@onready var _immobilize: Node2D = get_node_or_null("../Immobilize")


# ─────────────────────────────────────────────
# 生命周期
# ─────────────────────────────────────────────

func _ready() -> void:
	# 设置角色标识（Inspector 中若有覆盖值，则以 Inspector 为准）
	if character_id == "":
		character_id = "sun_wukong"
	if display_name == "":
		display_name = "齐天大圣"

	# 注册 4 个主动技能槽（initial_unlock=false，开局全部锁定，靠升级解锁）
	_register_skill(0, "毫毛分身", 12.0, false)
	_register_skill(1, "筋斗云", 8.0, false)
	_register_skill(2, "七十二变", 25.0, false)
	_register_skill(3, "定身术", 15.0, false)


# ─────────────────────────────────────────────
# 主动技能分发（override）
# ─────────────────────────────────────────────

## 玩家按下 1/2/3/4 后由 cast_skill() 调用。
## 返回 true 表示成功释放，基类随即启动 cooldown；false 不消耗 cooldown。
func _on_cast_skill(slot: int) -> bool:
	var player_node: Node = get_parent()
	if player_node == null:
		push_warning("SunWukongV2._on_cast_skill: no parent player node")
		return false

	match slot:
		0:
			if _hair_clone == null:
				push_warning("SunWukongV2._on_cast_skill: HairCloneV2 node not found")
				return false
			return _hair_clone.cast(player_node)
		1:
			if _cloud_step == null:
				push_warning("SunWukongV2._on_cast_skill: CloudStep node not found")
				return false
			return _cloud_step.cast(player_node)
		2:
			if _transform == null:
				push_warning("SunWukongV2._on_cast_skill: Transform72 node not found")
				return false
			return _transform.cast(player_node)
		3:
			if _immobilize == null:
				push_warning("SunWukongV2._on_cast_skill: Immobilize node not found")
				return false
			return _immobilize.cast(player_node)
		_:
			return false


# ─────────────────────────────────────────────
# 火眼金睛被动（override）
# ─────────────────────────────────────────────

## 对精英怪或 Boss 返回 1.2（+20% 伤害），其余返回 1.0。
## 由武器脚本（如 JinguBangV2）在造成伤害前查询，防御性检查 target 合法性。
func get_damage_modifier(target: Node) -> float:
	if target == null:
		return 1.0
	if target.is_in_group("bosses"):
		return 1.2
	if target.get("is_elite") == true:
		return 1.2
	return 1.0


# ─────────────────────────────────────────────
# 技能升级同步（override）
# ─────────────────────────────────────────────

## 先调 super 更新 _skill_levels / _skill_unlocked，
## 再把新等级同步到对应技能节点的 .level 字段。
## 技能节点各自的 level setter（_apply_level）会重新应用配置参数。
func apply_skill_upgrade(id: String) -> void:
	super.apply_skill_upgrade(id)

	# 仅处理孙悟空主动技能升级 id
	if not (id.begins_with("wukong_skill_unlock_") or id.begins_with("wukong_skill_upgrade_")):
		return

	# 解析槽位 suffix（"wukong_skill_unlock_N" 或 "wukong_skill_upgrade_N"）
	var suffix: String = ""
	if id.begins_with("wukong_skill_unlock_"):
		suffix = id.substr("wukong_skill_unlock_".length())
	else:
		suffix = id.substr("wukong_skill_upgrade_".length())

	if not suffix.is_valid_int():
		return

	var slot: int = int(suffix)
	if slot < 0 or slot > 3:
		return

	var new_level: int = get_skill_level(slot)

	# 找到对应技能节点并同步 level
	var target_node: Node2D = null
	match slot:
		0:
			target_node = _hair_clone
		1:
			target_node = _cloud_step
		2:
			target_node = _transform
		3:
			target_node = _immobilize

	if target_node != null and "level" in target_node:
		target_node.level = new_level


# ─────────────────────────────────────────────
# 升级池过滤（override）
# ─────────────────────────────────────────────

## 暂时返回空数组，表示使用默认升级池（W213 完善角色专属过滤）。
func _get_allowed_upgrade_ids() -> Array[String]:
	return []
