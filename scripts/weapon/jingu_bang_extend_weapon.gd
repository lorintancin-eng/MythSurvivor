class_name JinguBangExtendWeapon
extends WeaponBase

@export var stick_length: float = 600.0
@export var stick_width: float = 40.0
@export var knockback_distance: float = 80.0
@export var character_owner: String = "sun_wukong"
@export var element: String = "metal"


func _ready() -> void:
	if damage <= 0.0:
		damage = 35.0
	if cooldown <= 0.0:
		cooldown = 4.0


func _try_attack() -> bool:
	var target := _find_nearest_enemy()
	if target == null:
		return false
	var dir: Vector2 = (target.global_position - global_position).normalized()
	if dir.length_squared() < 0.000001:
		return false
	_perform_thrust(dir)
	return true


func _perform_thrust(dir: Vector2) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var half_width: float = stick_width * 0.5
	var dmg: float = _get_damage()
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		var to_enemy: Vector2 = enemy_node.global_position - global_position
		var along: float = to_enemy.dot(dir)
		if along < 0.0 or along > stick_length:
			continue
		var perpendicular: Vector2 = to_enemy - dir * along
		if perpendicular.length_squared() > half_width * half_width:
			continue
		enemy_node.call("take_damage", dmg)
		enemy_node.global_position += dir * knockback_distance
	_spawn_visual(dir)


func _spawn_visual(dir: Vector2) -> void:
	var line := Line2D.new()
	line.width = stick_width
	line.default_color = Color(0.95, 0.85, 0.45, 0.9)
	line.points = PackedVector2Array([Vector2.ZERO, dir * stick_length])
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.15)
	tween.tween_callback(line.queue_free)


func _find_nearest_enemy() -> Node2D:
	var attack_range_val := _get_attack_range()
	var nearest: Node2D = null
	var nearest_dist_sq: float = attack_range_val * attack_range_val
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		var dist_sq: float = global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq > nearest_dist_sq:
			continue
		nearest = enemy_node
		nearest_dist_sq = dist_sq
	return nearest
