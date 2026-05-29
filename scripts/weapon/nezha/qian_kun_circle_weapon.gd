class_name QianKunCircleWeapon
extends WeaponBase

## 乾坤圈 W203（哪吒升级解锁武器）
##
## Lv1: 锁定最近敌人，发射回旋镖；命中后折返玩家（两段伤害）
## Lv2: 折返时 AOE 40 范围
## Lv3: 双发（锁前 2 近）
## Lv4: 三才合击（TODO - MVP 简化为额外 +20% 伤害）
## damage 15→25, cooldown 2.2→1.8

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/QianKunProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var level: int = 1: set = _apply_level
@export var projectile_count: int = 1    # Lv3+ 变 2
@export var aoe_on_return: bool = false  # Lv2+ 折返 AOE
@export var sancai_bonus: bool = false   # Lv4 三才合击标记（MVP 简化为伤害加成）


func _ready() -> void:
	if damage <= 0.0:
		damage = 15.0
	if cooldown <= 0.0:
		cooldown = 2.2
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			damage = 15.0
			cooldown = 2.2
			projectile_count = 1
			aoe_on_return = false
			sancai_bonus = false
		2:
			damage = 18.0
			cooldown = 2.0
			projectile_count = 1
			aoe_on_return = true
			sancai_bonus = false
		3:
			damage = 22.0
			cooldown = 2.0
			projectile_count = 2
			aoe_on_return = true
			sancai_bonus = false
		4:
			damage = 25.0
			cooldown = 1.8
			projectile_count = 2
			aoe_on_return = true
			# MVP: 三才合击简化为伤害加成（真实版需召唤火尖枪/混天绫小型副本）
			sancai_bonus = true


## WeaponBase 攻击触发
func _try_attack() -> bool:
	var targets := _find_nearest_enemies(projectile_count)
	if targets.is_empty():
		return false

	var final_damage := _get_damage()
	# Lv4 MVP：三才合击加成 +20% 伤害（TODO: 完整版召唤小型副本武器）
	if sancai_bonus:
		final_damage *= 1.2

	var did_fire := false
	for target in targets:
		if _fire_projectile(target, final_damage):
			did_fire = true

	return did_fire


## 查找距离最近的前 N 个敌人
func _find_nearest_enemies(count: int) -> Array[Node2D]:
	var all_enemies: Array[Node2D] = []
	var attack_range_val := _get_attack_range()
	var range_sq := attack_range_val * attack_range_val

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > range_sq:
			continue
		all_enemies.append(enemy_node)

	# 按距离排序（最近优先）
	all_enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var da := global_position.distance_squared_to(a.global_position)
		var db := global_position.distance_squared_to(b.global_position)
		return da < db
	)

	var result: Array[Node2D] = []
	for i in range(mini(count, all_enemies.size())):
		result.append(all_enemies[i])
	return result


## 发射单个回旋镖到指定目标
func _fire_projectile(target: Node2D, proj_damage: float) -> bool:
	if projectile_scene == null:
		push_warning("QianKunCircleWeapon: projectile_scene is null.")
		return false

	var instance := projectile_scene.instantiate()
	if not instance is QianKunProjectile:
		push_error("QianKunCircleWeapon: projectile_scene must instantiate QianKunProjectile.")
		instance.queue_free()
		return false

	var projectile := instance as QianKunProjectile
	var parent := _get_projectile_parent()
	parent.add_child(projectile)
	projectile.global_position = global_position

	# owner 是 Player 节点，用于折返追踪
	var player_ref: Node2D = null
	if owner is Node2D:
		player_ref = owner as Node2D

	projectile.launch(
		target.global_position,
		proj_damage,
		player_ref,
		aoe_on_return
	)
	return true


func _get_projectile_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()
	return self
