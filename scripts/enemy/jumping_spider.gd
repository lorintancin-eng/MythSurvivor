class_name JumpingSpider
extends Enemy

## 跳蛛（L006 E505，蓄力 1s 跳扑）
##
## 行为：
## - 普通追击玩家
## - 每 jump_cooldown 秒，蓄力 1s（红圈警告）后跳扑到玩家位置，
##   落地时对玩家造成 jump_damage 伤害（半径 60px）
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L006

enum JumpState {
	CHASE,
	WINDUP,
	LANDING_CHECK,
}

@export var jump_cooldown: float = 3.5
@export var jump_windup_time: float = 1.0
@export var jump_land_radius: float = 60.0
@export var jump_damage: float = 16.0
@export var jump_linger_time: float = 0.18

var _jump_state: int = JumpState.CHASE
var _jump_timer: float = 0.0
var _jump_state_timer: float = 0.0
var _jump_target_pos: Vector2 = Vector2.ZERO
var _warning_circle: Polygon2D = null
var _land_flash: Polygon2D = null


func _ready() -> void:
	super._ready()
	_jump_timer = randf_range(1.5, jump_cooldown)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_cleanup_jump()
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _jump_state:
		JumpState.CHASE:
			_jump_timer -= delta
			velocity = (_player.global_position - global_position).normalized() * move_speed
			move_and_slide()
			_try_damage_player()
			if _jump_timer <= 0.0:
				_begin_windup()

		JumpState.WINDUP:
			velocity = Vector2.ZERO
			_jump_state_timer -= delta
			if _jump_state_timer <= 0.0:
				_execute_jump()

		JumpState.LANDING_CHECK:
			velocity = Vector2.ZERO
			_jump_state_timer -= delta
			if _jump_state_timer <= 0.0:
				_finish_jump()


func _begin_windup() -> void:
	_jump_state = JumpState.WINDUP
	_jump_state_timer = jump_windup_time
	_jump_target_pos = _player.global_position
	_show_warning_circle()


func _execute_jump() -> void:
	_remove_warning_circle()
	# 瞬移到目标位置
	global_position = _jump_target_pos
	_jump_state = JumpState.LANDING_CHECK
	_jump_state_timer = jump_linger_time
	_show_land_flash()
	# 落地伤害
	if is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist <= jump_land_radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", jump_damage)


func _finish_jump() -> void:
	_remove_land_flash()
	_jump_state = JumpState.CHASE
	_jump_timer = jump_cooldown


func _show_warning_circle() -> void:
	_remove_warning_circle()
	_warning_circle = Polygon2D.new()
	_warning_circle.color = Color(0.75, 0.2, 0.25, 0.45)
	_warning_circle.polygon = _make_circle_polygon(jump_land_radius, 24)
	if is_instance_valid(_player):
		var parent := _get_effect_parent()
		parent.add_child(_warning_circle)
		_warning_circle.global_position = _player.global_position


func _remove_warning_circle() -> void:
	if is_instance_valid(_warning_circle):
		_warning_circle.queue_free()
	_warning_circle = null


func _show_land_flash() -> void:
	_remove_land_flash()
	_land_flash = Polygon2D.new()
	_land_flash.color = Color(0.6, 0.25, 0.5, 0.65)
	_land_flash.polygon = _make_circle_polygon(jump_land_radius * 1.05, 24)
	var parent := _get_effect_parent()
	parent.add_child(_land_flash)
	_land_flash.global_position = global_position


func _remove_land_flash() -> void:
	if is_instance_valid(_land_flash):
		_land_flash.queue_free()
	_land_flash = null


func _cleanup_jump() -> void:
	_remove_warning_circle()
	_remove_land_flash()


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in maxi(point_count, 3):
		var angle := TAU * float(i) / float(maxi(point_count, 3))
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
