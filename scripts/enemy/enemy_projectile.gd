class_name EnemyProjectile
extends Area2D

## Enemy projectile (v0.5 L002, C01)
##
## Instantiated by RangedEnemy._fire_projectile().
## Call setup(direction, speed, damage, color) after instantiation.
## Hits player -> apply damage + queue_free.
## Exceeds max_lifetime -> queue_free.

@export var max_lifetime: float = 4.0
@export var hit_radius: float = 8.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 200.0
var _damage: float = 5.0
var _color: Color = Color(1, 1, 1, 1)
var _lifetime: float = 0.0
var _hit_player: bool = false

@onready var _body: Polygon2D = $Body
@onready var _collision: CollisionShape2D = $CollisionShape2D


func setup(direction: Vector2, speed: float, damage: float, color: Color = Color(1, 1, 1, 1)) -> void:
	_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_speed = maxf(speed, 0.0)
	_damage = maxf(damage, 0.0)
	_color = color
	if _body != null:
		_body.color = color
	rotation = _direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Ensure collision shape is set up if not already assigned in scene
	if _collision != null and _collision.shape == null:
		var shape := CircleShape2D.new()
		shape.radius = hit_radius
		_collision.shape = shape


func _physics_process(delta: float) -> void:
	if _hit_player:
		return
	_lifetime += delta
	if _lifetime >= max_lifetime:
		queue_free()
		return
	global_position += _direction * _speed * delta


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _try_hit(node: Node) -> void:
	if _hit_player:
		return
	# Walk up the tree to find the player group node
	var target: Node = node
	while target != null and not target.is_in_group("player"):
		target = target.get_parent()
	if target == null:
		return
	if target.has_method("take_damage"):
		target.call("take_damage", _damage)
		_hit_player = true
		queue_free()
