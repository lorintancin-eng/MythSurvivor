class_name ExperienceOrb
extends Area2D

@export var xp_value: float = 5.0

var _is_collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_try_collect_overlapping_bodies")


func _try_collect_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		if body is Node2D:
			_try_collect(body as Node2D)


func _on_body_entered(body: Node2D) -> void:
	_try_collect(body)


func _try_collect(body: Node2D) -> void:
	if _is_collected:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("gain_experience"):
		return

	_is_collected = true
	body.call("gain_experience", xp_value)
	queue_free()
