class_name StageDirector
extends Node2D

signal stage_time_changed(elapsed_time: float, stage_duration: float)
signal boss_warning_started(warning_lead_time: float)
signal boss_spawned(boss: Enemy)
signal stage_cleared(elapsed_time: float)
signal stage_failed(elapsed_time: float)

const DEFAULT_BOSS_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const MIN_STAGE_DURATION: float = 1.0
const MIN_SPAWN_DISTANCE: float = 80.0

@export var player_path: NodePath = ^"../Player"
@export var enemy_spawner_path: NodePath = ^"../EnemySpawner"
@export var boss_scene: PackedScene = DEFAULT_BOSS_SCENE
@export var stage_duration: float = 300.0
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
@export var boss_move_speed: float = 70.0
@export var boss_max_hp: float = 260.0
@export var boss_damage: float = 16.0
@export var boss_scale: float = 1.8
@export var boss_phase_spawn_interval: float = 2.5
@export var boss_phase_max_enemies: int = 8

var elapsed_time: float = 0.0

var _is_boss_warning_started: bool = false
var _is_boss_spawned: bool = false
var _is_stage_cleared: bool = false
var _is_stage_failed: bool = false
var _rng := RandomNumberGenerator.new()
var _player: Player
var _enemy_spawner: EnemySpawner


func _ready() -> void:
	stage_duration = maxf(stage_duration, MIN_STAGE_DURATION)
	boss_warning_lead_time = clampf(boss_warning_lead_time, 0.0, stage_duration)
	boss_spawn_distance = maxf(boss_spawn_distance, MIN_SPAWN_DISTANCE)
	boss_max_hp = maxf(boss_max_hp, 1.0)
	boss_damage = maxf(boss_damage, 0.0)
	boss_scale = maxf(boss_scale, 0.1)
	_rng.randomize()

	_player = get_node_or_null(player_path) as Player
	_enemy_spawner = get_node_or_null(enemy_spawner_path) as EnemySpawner
	if _player != null and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)

	stage_time_changed.emit(elapsed_time, stage_duration)


func _process(delta: float) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	elapsed_time = minf(elapsed_time + delta, stage_duration)
	stage_time_changed.emit(elapsed_time, stage_duration)

	if not _is_boss_warning_started and elapsed_time >= stage_duration - boss_warning_lead_time:
		_is_boss_warning_started = true
		boss_warning_started.emit(boss_warning_lead_time)

	if not _is_boss_spawned and elapsed_time >= stage_duration:
		_spawn_boss()


func _spawn_boss() -> void:
	_is_boss_spawned = true
	_apply_boss_phase_spawn_pressure()

	if boss_scene == null:
		push_warning("StageDirector has no boss_scene.")
		return

	var boss_instance := boss_scene.instantiate()
	if not boss_instance is Enemy:
		push_error("StageDirector boss_scene must instantiate an Enemy.")
		boss_instance.queue_free()
		return

	var boss := boss_instance as Enemy
	boss.name = "FamineBeastBoss"
	boss.move_speed = boss_move_speed
	boss.max_hp = boss_max_hp
	boss.damage = boss_damage
	boss.xp_drop_value = 0.0
	boss.scale = Vector2.ONE * boss_scale
	boss.died.connect(_on_boss_died)

	_get_spawn_parent().add_child(boss)
	boss.global_position = _get_boss_spawn_position()
	boss_spawned.emit(boss)


func _apply_boss_phase_spawn_pressure() -> void:
	if _enemy_spawner == null:
		return

	_enemy_spawner.spawn_interval = maxf(_enemy_spawner.spawn_interval, boss_phase_spawn_interval)
	if boss_phase_max_enemies >= 0:
		_enemy_spawner.max_enemies = mini(_enemy_spawner.max_enemies, boss_phase_max_enemies)


func _get_spawn_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self


func _get_boss_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	return player_position + Vector2.RIGHT.rotated(angle) * boss_spawn_distance


func _on_boss_died(_boss: Enemy) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_cleared = true
	if _enemy_spawner != null:
		_enemy_spawner.set_spawning_enabled(false)
	stage_cleared.emit(elapsed_time)


func _on_player_died() -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_failed = true
	stage_failed.emit(elapsed_time)
