class_name HairCloneWeapon
extends WeaponBase

## 毫毛分身武器（W103）
##
## 每 8s 撒出 3 根毫毛 → 3 只小猴朝不同方向移动 → 碰敌自爆 70 px
## 详细设计：docs/04_SKILL_DESIGN.md §5.2 W103

@export var clone_count: int = 3
@export var clone_speed: float = 200.0
@export var clone_lifetime: float = 6.0
@export var explosion_radius: float = 70.0
@export var explosion_damage: float = 25.0
@export var character_owner: String = "sun_wukong"
@export var element: String = "neutral"  # 召唤系，无元素


func _ready() -> void:
	if cooldown <= 0.0:
		cooldown = 8.0


func _try_attack() -> bool:
	_spawn_clones()
	return true


func _spawn_clones() -> void:
	var parent := _get_projectile_parent()
	if parent == null:
		return
	# 3 只小猴均匀散布（基础角随机 + 每只偏移 120° + 随机扰动 ±45°）
	var base_angle: float = randf() * TAU
	for i in clone_count:
		var angle: float = base_angle + (TAU / clone_count) * i + randf_range(-PI / 4.0, PI / 4.0)
		var clone := HairClone.new()
		clone.direction = Vector2.RIGHT.rotated(angle)
		clone.move_speed = clone_speed
		clone.lifetime = clone_lifetime
		clone.explosion_radius = explosion_radius
		clone.explosion_damage = explosion_damage
		clone.global_position = global_position
		parent.add_child(clone)


# 让小猴挂在 scene root 而非武器节点下（避免随玩家移动）
func _get_projectile_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root
