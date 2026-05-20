class_name EnemySpawner
extends Node2D

signal enemy_defeated(defeated_count: int)

const DEFAULT_ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")

@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var spawn_interval: float = 1.25
@export var max_enemies: int = 18
@export var spawn_margin: float = 80.0
@export var random_seed: int = 1301
@export var is_spawning_enabled: bool = true

var current_enemy_count: int = 0
var defeated_enemy_count: int = 0

var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0


func _ready() -> void:
	_rng.seed = random_seed
	_spawn_timer = maxf(spawn_interval, 0.1)


func _process(delta: float) -> void:
	if not is_spawning_enabled or enemy_scene == null or max_enemies <= 0:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	_spawn_timer += maxf(spawn_interval, 0.1)
	_try_spawn_enemy()


func _try_spawn_enemy() -> void:
	if current_enemy_count >= max_enemies:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_warning("EnemySpawner could not find a node in the player group.")
		return

	var enemy_instance := enemy_scene.instantiate()
	if not enemy_instance is Enemy:
		push_error("EnemySpawner enemy_scene must instantiate an Enemy.")
		enemy_instance.queue_free()
		return

	var enemy := enemy_instance as Enemy
	add_child(enemy)
	enemy.global_position = _get_spawn_position(player.global_position)
	enemy.died.connect(_on_enemy_died)
	current_enemy_count += 1


func set_spawning_enabled(is_enabled: bool) -> void:
	is_spawning_enabled = is_enabled


func _get_spawn_position(player_position: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var camera_zoom := Vector2.ONE
	if camera != null:
		camera_zoom = camera.zoom

	var half_visible_size := viewport_size * 0.5 / camera_zoom
	var side := _rng.randi_range(0, 3)
	var offset := Vector2.ZERO

	match side:
		0:
			offset.x = -half_visible_size.x - spawn_margin
			offset.y = _rng.randf_range(-half_visible_size.y, half_visible_size.y)
		1:
			offset.x = half_visible_size.x + spawn_margin
			offset.y = _rng.randf_range(-half_visible_size.y, half_visible_size.y)
		2:
			offset.x = _rng.randf_range(-half_visible_size.x, half_visible_size.x)
			offset.y = -half_visible_size.y - spawn_margin
		_:
			offset.x = _rng.randf_range(-half_visible_size.x, half_visible_size.x)
			offset.y = half_visible_size.y + spawn_margin

	return player_position + offset


func _on_enemy_died(_enemy: Enemy) -> void:
	current_enemy_count = maxi(current_enemy_count - 1, 0)
	defeated_enemy_count += 1
	enemy_defeated.emit(defeated_enemy_count)
