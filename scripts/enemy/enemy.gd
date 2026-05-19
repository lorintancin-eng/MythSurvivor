class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

const MIN_DAMAGE_INTERVAL: float = 0.1
const HEALTH_BAR_WIDTH: float = 28.0
const HEALTH_BAR_HEIGHT: float = 4.0

@export var move_speed: float = 90.0
@export var max_hp: float = 24.0
@export var damage: float = 8.0
@export var damage_interval: float = 0.8

var current_hp: float = 0.0

var _damage_cooldown: float = 0.0
var _damage_targets: Array[Node] = []
var _is_dead: bool = false
var _player: Node2D

@onready var _damage_area: Area2D = $DamageArea
@onready var _health_fill: Polygon2D = $HealthBar/Fill


func _ready() -> void:
	add_to_group("enemies")
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	_damage_area.body_entered.connect(_on_damage_body_entered)
	_damage_area.body_exited.connect(_on_damage_body_exited)
	_update_health_bar()
	_find_player()


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var move_direction := global_position.direction_to(_player.global_position)
	velocity = move_direction * move_speed
	move_and_slide()

	_try_damage_player()


func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_hp = maxf(current_hp - amount, 0.0)
	_update_health_bar()
	if current_hp <= 0.0:
		_die()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _try_damage_player() -> void:
	if _damage_cooldown > 0.0 or damage <= 0.0:
		return

	for target in _damage_targets:
		if _is_player_damage_target(target):
			target.call("take_damage", damage)
			_damage_cooldown = maxf(damage_interval, MIN_DAMAGE_INTERVAL)
			return


func _is_player_damage_target(target: Object) -> bool:
	if not target is Node:
		return false

	var target_node := target as Node
	return target_node.is_in_group("player") and target.has_method("take_damage")


func _update_health_bar() -> void:
	if _health_fill == null:
		return

	var health_ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	var left := -HEALTH_BAR_WIDTH * 0.5
	var right := left + HEALTH_BAR_WIDTH * health_ratio
	var top := -HEALTH_BAR_HEIGHT * 0.5
	var bottom := HEALTH_BAR_HEIGHT * 0.5
	_health_fill.polygon = PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom),
	])


func _on_damage_body_entered(body: Node2D) -> void:
	if _is_player_damage_target(body) and not _damage_targets.has(body):
		_damage_targets.append(body)


func _on_damage_body_exited(body: Node2D) -> void:
	_damage_targets.erase(body)


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	died.emit(self)
	queue_free()
