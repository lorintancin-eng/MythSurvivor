class_name FireSpearProjectile
extends Area2D

## 火尖枪投射物（火球）
##
## 支持穿透（pierce_count >= 1 表示可额外穿透的敌人数）。
## pierce_count = 1 时可穿透 1 个敌人后销毁（Lv1-2 默认）。
## pierce_count = 2 时可穿透 2 个（Lv3-4）。

const MIN_DIRECTION_LENGTH: float = 0.001

var damage: float = 0.0
var speed: float = 0.0
var max_distance: float = 0.0
var lifetime: float = 0.0
var pierce_count: int = 1

var _direction: Vector2 = Vector2.RIGHT
var _elapsed_time: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _pierce_remaining: int = 0
var _is_launched: bool = false
# 命中冷却：避免同一帧重复判定同一敌人
var _hit_enemies: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _is_launched:
		return

	global_position += _direction * speed * delta
	_elapsed_time += delta

	var distance_squared := global_position.distance_squared_to(_start_position)
	if _elapsed_time >= lifetime or distance_squared >= max_distance * max_distance:
		queue_free()


func launch(
	new_direction: Vector2,
	new_damage: float,
	new_speed: float,
	new_max_distance: float,
	new_lifetime: float,
	new_pierce_count: int = 1
) -> void:
	if new_direction.length_squared() <= MIN_DIRECTION_LENGTH * MIN_DIRECTION_LENGTH:
		_direction = Vector2.RIGHT
	else:
		_direction = new_direction.normalized()

	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.0)
	max_distance = maxf(new_max_distance, 1.0)
	lifetime = maxf(new_lifetime, 0.05)
	pierce_count = maxi(new_pierce_count, 0)
	_pierce_remaining = pierce_count
	_elapsed_time = 0.0
	_start_position = global_position
	_hit_enemies.clear()
	_is_launched = true
	rotation = _direction.angle()
	set_physics_process(true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return
	if _hit_enemies.has(body):
		return

	_hit_enemies.append(body)
	body.call("take_damage", damage)

	# 消耗一次穿透次数
	if _pierce_remaining <= 0:
		queue_free()
	else:
		_pierce_remaining -= 1
