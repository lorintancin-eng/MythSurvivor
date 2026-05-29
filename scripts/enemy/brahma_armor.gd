class_name BrahmaArmor
extends Enemy

## 梵天魔甲（L010 E904，肉盾，死亡留 BURN+CURSE 双区）
##
## 行为：
## - 持续追击玩家（使用基类 _physics_process）
## - 死亡时在原地生成 BURN TerrainEffect 区域 4s + CURSE TerrainEffect 区域 4s
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L010

const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

@export var burn_radius: float = 65.0
@export var burn_duration: float = 4.0
@export var burn_dps: float = 6.0
@export var curse_radius: float = 55.0
@export var curse_duration: float = 4.0


func _die() -> void:
	_spawn_burn_terrain()
	_spawn_curse_terrain()
	super._die()


func _spawn_burn_terrain() -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.BURN
	te.effect_radius = burn_radius
	te.burn_dps = burn_dps
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = global_position
	var timer := get_tree().create_timer(burn_duration)
	timer.timeout.connect(te.queue_free)


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
