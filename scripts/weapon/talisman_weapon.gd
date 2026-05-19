class_name TalismanWeapon
extends WeaponBase

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/TalismanProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE


func _try_attack() -> bool:
	var target := _find_nearest_enemy()
	if target == null:
		return false

	return _fire_projectile(target)


func _find_nearest_enemy() -> Node2D:
	var range := _get_attack_range()
	var nearest_enemy: Node2D = null
	var nearest_distance_squared := range * range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue

		var distance_squared := global_position.distance_squared_to(enemy_node.global_position)
		if distance_squared > nearest_distance_squared:
			continue

		nearest_enemy = enemy_node
		nearest_distance_squared = distance_squared

	return nearest_enemy


func _fire_projectile(target: Node2D) -> bool:
	if projectile_scene == null:
		push_warning("TalismanWeapon has no projectile scene.")
		return false

	var projectile_instance := projectile_scene.instantiate()
	if not projectile_instance is TalismanProjectile:
		push_error("TalismanWeapon projectile_scene must instantiate a TalismanProjectile.")
		projectile_instance.queue_free()
		return false

	var projectile := projectile_instance as TalismanProjectile
	var projectile_parent := _get_projectile_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = global_position

	var direction := global_position.direction_to(target.global_position)
	projectile.launch(
		direction,
		_get_damage(),
		_get_projectile_speed(),
		_get_attack_range(),
		_get_projectile_lifetime()
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
