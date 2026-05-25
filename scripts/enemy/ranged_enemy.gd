class_name RangedEnemy
extends Enemy

## Ranged enemy base class (v0.5 L002, C01)
##
## Behavior:
## - distance > preferred_distance + band  : approach player
## - distance < preferred_distance - band  : back away
## - distance within band                  : stand still + fire on timer
##
## Zero-intrusion: overrides _physics_process only.
## All base class fields (_is_dead, _damage_cooldown, _player, etc.) are
## accessed by name as GDScript has no true access control.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy/EnemyProjectile.tscn")

@export var attack_range: float = 250.0
@export var preferred_distance: float = 200.0
@export var distance_band: float = 30.0
@export var projectile_damage: float = 8.0
@export var projectile_speed: float = 220.0
@export var fire_interval: float = 1.8
@export var projectile_color: Color = Color(0.3, 0.8, 0.9, 0.9)

var _fire_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_fire_timer = maxf(_fire_timer - delta, 0.0)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = Vector2.ZERO

	if distance > preferred_distance + distance_band:
		direction = to_player.normalized()
	elif distance < preferred_distance - distance_band:
		direction = -to_player.normalized()
	else:
		# Within standing band: stop and try to fire
		direction = Vector2.ZERO
		if distance <= attack_range and _fire_timer <= 0.0:
			_fire_projectile()
			_fire_timer = fire_interval

	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


func _fire_projectile() -> void:
	if not is_instance_valid(_player):
		return
	var projectile: Node = PROJECTILE_SCENE.instantiate()
	if projectile == null:
		return
	var parent: Node = _get_projectile_parent()
	parent.add_child(projectile)
	projectile.global_position = global_position
	var fire_direction: Vector2 = (_player.global_position - global_position).normalized()
	if projectile.has_method("setup"):
		projectile.setup(fire_direction, projectile_speed, projectile_damage, projectile_color)


func _get_projectile_parent() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene
	var parent: Node = get_parent()
	if parent != null:
		return parent
	return self
