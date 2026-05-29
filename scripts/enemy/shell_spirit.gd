class_name ShellSpirit
extends Enemy

## 贝壳精（L004 E305，自爆型）
##
## 行为：
## - 静止不移动（move_speed=0）
## - 玩家进入 explode_trigger_distance (50px) 触发自爆警告
## - 自爆：白色预警 0.5s → 爆炸 70px/20dmg → die（无 BURN 区）
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L004

@export var explode_trigger_distance: float = 50.0
@export var explode_warning_time: float = 0.5
@export var explode_radius: float = 70.0
@export var explode_damage: float = 20.0
@export var warning_color: Color = Color(0.8, 0.8, 1.0, 0.55)

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
		# 静止不动
		velocity = Vector2.ZERO
		move_and_slide()


func _start_warning() -> void:
	if _is_exploding:
		return
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
	_die()


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
