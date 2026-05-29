class_name CocoonDemon
extends Enemy

## 茧妖（L006 E503，肉盾死亡分裂 4 毒蛛）
##
## 行为：
## - 缓慢追击玩家（使用基类 _physics_process）
## - 死亡时在原地分裂出 4 只毒蛛（PoisonSpider 场景）
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L006

const POISON_SPIDER_SCENE: PackedScene = preload("res://scenes/enemy/PoisonSpider.tscn")
const POISON_SPIDER_ARCHETYPE: Resource = preload("res://resources/enemies/poison_spider.tres")

@export var split_count: int = 4
@export var split_spawn_radius: float = 40.0


func _die() -> void:
	_spawn_split_spiders()
	super._die()


func _spawn_split_spiders() -> void:
	if POISON_SPIDER_SCENE == null:
		return
	var parent := _get_split_parent()
	for i in range(split_count):
		var spider := POISON_SPIDER_SCENE.instantiate()
		if spider == null:
			continue
		parent.add_child(spider)
		var angle := TAU * float(i) / float(split_count)
		var offset := Vector2.RIGHT.rotated(angle) * split_spawn_radius
		spider.global_position = global_position + offset
		if POISON_SPIDER_ARCHETYPE != null:
			if "max_hp" in spider:
				spider.max_hp = POISON_SPIDER_ARCHETYPE.max_hp
			if "current_hp" in spider:
				spider.current_hp = POISON_SPIDER_ARCHETYPE.max_hp
			if "move_speed" in spider:
				spider.move_speed = POISON_SPIDER_ARCHETYPE.move_speed
			if "damage" in spider:
				spider.damage = POISON_SPIDER_ARCHETYPE.damage
			if "xp_drop_value" in spider:
				spider.xp_drop_value = POISON_SPIDER_ARCHETYPE.xp_drop_value


func _get_split_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
