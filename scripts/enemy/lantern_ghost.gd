class_name LanternGhost
extends Enemy

## 灯笼鬼（L002 D02，自爆型）
##
## 行为：
## - 持续追击玩家
## - 距离 < explode_trigger_distance 触发自爆
## - 自爆：红色预警 0.5s → AOE 伤害 → die
## - 不计入 contact 伤害（damage=0，靠 burst）
##
## 设计参考 docs/L002_GHOST_MARKET_DESIGN.md §4.1

@export var explode_trigger_distance: float = 50.0
@export var explode_warning_time: float = 0.5
@export var explode_radius: float = 70.0
@export var explode_damage: float = 25.0
@export var warning_color: Color = Color(1.0, 0.2, 0.1, 0.5)

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
	_die()
