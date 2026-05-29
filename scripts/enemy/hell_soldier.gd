class_name HellSoldier
extends Enemy

## 冥卒（L008 E701，死亡留 CURSE 区）
##
## 行为：
## - 持续追击玩家（使用基类 _physics_process）
## - 死亡时在原地生成 CURSE TerrainEffect 区域 2s
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L008

const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

@export var curse_radius: float = 50.0
@export var curse_duration: float = 2.0


func _die() -> void:
	_spawn_curse_terrain()
	super._die()


func _spawn_curse_terrain() -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.CURSE
	te.effect_radius = curse_radius
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = global_position
	var timer := get_tree().create_timer(curse_duration)
	timer.timeout.connect(te.queue_free)


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
