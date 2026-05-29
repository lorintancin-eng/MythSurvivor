class_name JudgeSoul
extends Enemy

## 判官魂（L008 E705，光环 +20% 伤）
##
## 行为：
## - 追击玩家
## - 光环：周围 aura_radius px 内敌人 damage * (1 + aura_damage_bonus)
## - 视觉：幽碧半透明圆圈（_draw）
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L008

@export var aura_radius: float = 140.0
@export var aura_damage_bonus: float = 0.20
@export var aura_color: Color = Color(0.3, 0.65, 0.4, 0.18)

## {enemy_node -> original_damage}
var _affected_enemies: Dictionary = {}


func _physics_process(delta: float) -> void:
	if _is_dead:
		_clear_all_buffs()
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = (_player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()

	_apply_aura()
	queue_redraw()


func _apply_aura() -> void:
	var aura_sq: float = aura_radius * aura_radius
	var current_affected: Dictionary = {}

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == self:
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var dist_sq: float = global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq > aura_sq:
			continue
		current_affected[enemy_node] = true
		if not _affected_enemies.has(enemy_node):
			if "damage" in enemy_node:
				_affected_enemies[enemy_node] = enemy_node.damage
				enemy_node.damage = enemy_node.damage * (1.0 + aura_damage_bonus)

	var to_remove: Array = []
	for enemy in _affected_enemies.keys():
		if not is_instance_valid(enemy) or not current_affected.has(enemy):
			if is_instance_valid(enemy) and "damage" in enemy:
				enemy.damage = _affected_enemies[enemy]
			to_remove.append(enemy)
	for key in to_remove:
		_affected_enemies.erase(key)


func _clear_all_buffs() -> void:
	for enemy in _affected_enemies.keys():
		if is_instance_valid(enemy) and "damage" in enemy:
			enemy.damage = _affected_enemies[enemy]
	_affected_enemies.clear()


func _draw() -> void:
	var points := PackedVector2Array()
	var segments: int = 32
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		points.append(Vector2.RIGHT.rotated(ang) * aura_radius)
	draw_colored_polygon(points, aura_color)
