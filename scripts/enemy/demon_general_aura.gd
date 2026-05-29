class_name DemonGeneralAura
extends Enemy

## 妖将光环（L010 E905，光环回血 5/s + 速 +20%，最危险）
##
## 行为：
## - 追击玩家
## - 光环：周围 aura_radius px 内敌人每秒回血 hp_regen_per_second，move_speed ×1.20
## - 视觉：金焰半透明圆圈（_draw）
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L010

@export var aura_radius: float = 150.0
@export var aura_speed_bonus: float = 0.20
@export var hp_regen_per_second: float = 5.0
@export var aura_color: Color = Color(0.85, 0.75, 0.2, 0.18)

## {enemy_node -> original_move_speed}
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

	_apply_aura(delta)
	queue_redraw()


func _apply_aura(delta: float) -> void:
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

		# 回血：每帧增加 HP，不超过最大值
		if "current_hp" in enemy_node and "max_hp" in enemy_node:
			enemy_node.current_hp = minf(
				float(enemy_node.current_hp) + hp_regen_per_second * delta,
				float(enemy_node.max_hp)
			)

		# 速度加成（仅首次进入时叠加）
		if not _affected_enemies.has(enemy_node):
			if "move_speed" in enemy_node:
				_affected_enemies[enemy_node] = enemy_node.move_speed
				enemy_node.move_speed = enemy_node.move_speed * (1.0 + aura_speed_bonus)

	# 移除已离开光环的敌人速度加成
	var to_remove: Array = []
	for enemy in _affected_enemies.keys():
		if not is_instance_valid(enemy) or not current_affected.has(enemy):
			if is_instance_valid(enemy) and "move_speed" in enemy:
				enemy.move_speed = _affected_enemies[enemy]
			to_remove.append(enemy)
	for key in to_remove:
		_affected_enemies.erase(key)


func _clear_all_buffs() -> void:
	for enemy in _affected_enemies.keys():
		if is_instance_valid(enemy) and "move_speed" in enemy:
			enemy.move_speed = _affected_enemies[enemy]
	_affected_enemies.clear()


func _draw() -> void:
	var points := PackedVector2Array()
	var segments: int = 32
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		points.append(Vector2.RIGHT.rotated(ang) * aura_radius)
	draw_colored_polygon(points, aura_color)
