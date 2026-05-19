class_name Player
extends CharacterBody2D

signal died

const HEALTH_BAR_WIDTH: float = 36.0
const HEALTH_BAR_HEIGHT: float = 5.0

@export var move_speed: float = 180.0
@export var max_hp: float = 100.0

var current_hp: float = 0.0

var _is_dead: bool = false

@onready var _health_fill: Polygon2D = $HealthBar/Fill


func _ready() -> void:
	_ensure_input_actions()
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	_update_health_bar()


func _physics_process(_delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * move_speed
	move_and_slide()


func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_hp = maxf(current_hp - amount, 0.0)
	_update_health_bar()
	if current_hp <= 0.0:
		_die()


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


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()


func _ensure_input_actions() -> void:
	var action_events := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
	}

	for action_name in action_events.keys():
		var action_key := StringName(action_name)
		if not InputMap.has_action(action_key):
			InputMap.add_action(action_key)

		for keycode in action_events[action_name]:
			var event_keycode: int = keycode
			if _action_has_key(action_key, event_keycode):
				continue

			var event := InputEventKey.new()
			event.keycode = event_keycode
			InputMap.action_add_event(action_key, event)


func _action_has_key(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode:
				return true

	return false
