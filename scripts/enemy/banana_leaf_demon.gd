class_name BananaLeafDemon
extends Enemy

## 芭蕉叶妖（L005 E404，自爆型）
##
## 行为：
## - 持续追击玩家
## - 距离 < explode_trigger_distance 触发自爆
## - 自爆：绿色预警 0.5s → AOE 伤害 → 原地生成 BURN TerrainEffect 区域 → die
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L005

const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

@export var explode_trigger_distance: float = 55.0
@export var explode_warning_time: float = 0.5
@export var explode_radius: float = 65.0
@export var explode_damage: float = 7.0
@export var warning_color: Color = Color(0.3, 0.9, 0.2, 0.5)
@export var burn_radius: float = 55.0
@export var burn_duration: float = 2.0
@export var burn_dps: float = 6.0

var _is_exploding: bool = false
var _explode_timer: float = 0.0
var _warning_circle: Polygon2D = null


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	if _is_exploding:
		_explode_timer -= delta
		if _explode_timer <= 0.0:
			_do_explode()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance: float = global_position.distance_to(_player.global_position)
	if distance <= explode_trigger_distance:
		_start_warning()
	else:
		var direction: Vector2 = (_player.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()


func _start_warning() -> void:
	_is_exploding = true
	_explode_timer = explode_warning_time
	_warning_circle = Polygon2D.new()
	_warning_circle.color = warning_color
	var points := PackedVector2Array()
	var segments: int = 24
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		points.append(Vector2.RIGHT.rotated(ang) * explode_radius)
	_warning_circle.polygon = points
	add_child(_warning_circle)


func _do_explode() -> void:
	if is_instance_valid(_warning_circle):
		_warning_circle.queue_free()
	if is_instance_valid(_player):
		var distance: float = global_position.distance_to(_player.global_position)
		if distance <= explode_radius and _player.has_method("take_damage"):
			_player.take_damage(explode_damage)
	_spawn_burn_terrain()
	_die()


func _spawn_burn_terrain() -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.BURN
	te.effect_radius = burn_radius
	te.burn_dps = burn_dps
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = global_position
	# 定时销毁 BURN 区
	var timer := get_tree().create_timer(burn_duration)
	timer.timeout.connect(te.queue_free)


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
