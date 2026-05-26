class_name BreakableObject
extends StaticBody2D

## Breakable object (L003 G02, v0.6 new mechanic)
##
## Decision D3: fixed drop of 4 XP orbs on destruction.
## Weapon hit detection: BreakableObject extends StaticBody2D with collision_layer=1
## so projectile body_entered signals can detect it (same layer as enemies).
## Also added to group "enemies" so AoE weapons using get_nodes_in_group work.
## On break, does not count as enemy kill (no enemy_killed signal emitted).
## extra_drops field reserved for v0.7+ material system expansion.

const DEFAULT_ORB_SCENE: PackedScene = preload("res://scenes/system/ExperienceOrb.tscn")

@export var max_hp: float = 30.0
@export var drop_orb_count: int = 4
@export var drop_orb_xp_value: float = 4.0
@export var drop_orb_radius: float = 36.0
@export var extra_drops: Array[PackedScene] = []
@export var body_color: Color = Color(0.4, 0.5, 0.6, 0.85)
@export var body_scale: float = 1.3

var current_hp: float = 0.0
var _is_broken: bool = false

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("breakables")
	current_hp = max_hp
	if _body != null:
		_body.color = body_color
		_body.scale = Vector2(body_scale, body_scale)


## Called by weapons to apply damage.
func take_damage(amount: float) -> void:
	if _is_broken or amount <= 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	if current_hp <= 0.0:
		_break()


func _break() -> void:
	if _is_broken:
		return
	_is_broken = true
	_spawn_orbs()
	_spawn_extra_drops()
	queue_free()


func _spawn_orbs() -> void:
	var scene: PackedScene = DEFAULT_ORB_SCENE
	if scene == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	for i in range(drop_orb_count):
		var orb: Node = scene.instantiate()
		if orb == null:
			continue
		var angle: float = TAU * float(i) / float(maxi(drop_orb_count, 1))
		var offset: Vector2 = Vector2.RIGHT.rotated(angle) * drop_orb_radius
		current_scene.add_child(orb)
		if orb is Node2D:
			(orb as Node2D).global_position = global_position + offset
		if "xp_value" in orb:
			orb.xp_value = drop_orb_xp_value


func _spawn_extra_drops() -> void:
	if extra_drops.is_empty():
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	for drop_scene in extra_drops:
		if drop_scene == null:
			continue
		var drop: Node = drop_scene.instantiate()
		if drop == null:
			continue
		current_scene.add_child(drop)
		if drop is Node2D:
			(drop as Node2D).global_position = global_position
