class_name FireSpearWeapon
extends WeaponBase

## 火尖枪 W201（哪吒初始武器）
##
## Lv1: 前方扇形 3 发火球，穿透 1 个敌人
## Lv2: 5 发 + 增强灼烧（伤害/冷却提升）
## Lv3: 5 发 + 穿透 2 + 灼烧强化
## Lv4: 5 发 + 穿透 2 + 最强参数
##
## 三昧真火爆发：consume_fire() 返回 true 时
##   本次 damage * FIRE_BURST_DAMAGE_MULT，range * fire_burst_range_mult
##
## TODO(N03+): 灼烧地面区域（burn_dps 当前未作地面区域，仅保留参数预留）

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapon/FireSpearProjectile.tscn")

@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var level: int = 1: set = _apply_level
@export var projectile_count: int = 3
@export var pierce_count: int = 1
@export var burn_dps: float = 8.0
@export var burn_duration: float = 0.5

# 扇形张角（度），投射物在此角度内均匀分布
var _spread_deg: float = 30.0


func _ready() -> void:
	if damage <= 0.0:
		damage = 12.0
	if cooldown <= 0.0:
		cooldown = 1.6
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			damage = 12.0
			cooldown = 1.6
			projectile_count = 3
			pierce_count = 1
			burn_dps = 8.0
			burn_duration = 0.5
			_spread_deg = 30.0
		2:
			damage = 14.0
			cooldown = 1.5
			projectile_count = 5
			pierce_count = 1
			burn_dps = 12.0
			burn_duration = 0.5
			_spread_deg = 40.0
		3:
			damage = 16.0
			cooldown = 1.4
			projectile_count = 5
			pierce_count = 2
			burn_dps = 12.0
			burn_duration = 0.8
			_spread_deg = 40.0
		4:
			damage = 18.0
			cooldown = 1.3
			projectile_count = 5
			pierce_count = 2
			burn_dps = 12.0
			burn_duration = 0.8
			_spread_deg = 40.0


## WeaponBase 的攻击触发（由 WeaponBase._process 冷却门控后调用）
func _try_attack() -> bool:
	# 查找最近敌人以确定射击方向
	var target := _find_nearest_enemy()
	# 若无敌人在范围内，仍可触发（朝 facing 方向）
	var fire_direction := _get_fire_direction(target)

	# 查询三昧真火爆发（消耗 Nezha 的能量）
	var is_burst := _check_fire_burst()
	var burst_damage_mult := 1.0
	var burst_range_mult := 1.0
	if is_burst:
		burst_damage_mult = _get_burst_damage_mult()
		burst_range_mult = _get_burst_range_mult()

	return _fire_projectiles(fire_direction, burst_damage_mult, burst_range_mult)


## 获取射击方向：优先朝最近敌人，无目标时朝玩家 facing
func _get_fire_direction(target: Node2D) -> Vector2:
	if target != null:
		return global_position.direction_to(target.global_position)
	# 无敌人时朝 facing
	if owner != null and "facing" in owner:
		var f: Vector2 = owner.facing
		if f.length_squared() > 0.001:
			return f.normalized()
	return Vector2.RIGHT


## 查找范围内最近敌人（略微扩大范围避免无目标时不攻击）
func _find_nearest_enemy() -> Node2D:
	var range_val := _get_attack_range()
	var nearest_enemy: Node2D = null
	var nearest_dist_sq := range_val * range_val

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		var dist_sq := global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq > nearest_dist_sq:
			continue
		nearest_enemy = enemy_node
		nearest_dist_sq = dist_sq

	return nearest_enemy


## 扇形发射多发火球
func _fire_projectiles(
	base_direction: Vector2,
	damage_mult: float,
	range_mult: float
) -> bool:
	var count := maxi(projectile_count, 1)
	var spread_rad := deg_to_rad(maxf(_spread_deg, 0.0))
	var start_offset := -spread_rad * float(count - 1) * 0.5
	var did_fire := false

	for i in range(count):
		var direction := base_direction.rotated(start_offset + spread_rad * float(i))
		if _fire_single(direction, damage_mult, range_mult):
			did_fire = true

	return did_fire


func _fire_single(direction: Vector2, damage_mult: float, range_mult: float) -> bool:
	if projectile_scene == null:
		push_warning("FireSpearWeapon: projectile_scene is null.")
		return false

	var instance := projectile_scene.instantiate()
	if not instance is FireSpearProjectile:
		push_error("FireSpearWeapon: projectile_scene must instantiate FireSpearProjectile.")
		instance.queue_free()
		return false

	var projectile := instance as FireSpearProjectile
	var parent := _get_projectile_parent()
	parent.add_child(projectile)
	projectile.global_position = global_position

	var final_damage := _get_damage() * damage_mult
	var final_range := _get_attack_range() * range_mult
	var final_lifetime := _get_projectile_lifetime() * range_mult  # 范围扩大时生命延长

	projectile.launch(
		direction,
		final_damage,
		_get_projectile_speed(),
		final_range,
		final_lifetime,
		pierce_count
	)
	return true


## 向 Nezha 角色基类查询并消耗三昧真火
## owner 是 Player 节点，player._character_base 是 Nezha 实例
func _check_fire_burst() -> bool:
	if owner == null:
		return false
	if not "_character_base" in owner:
		return false
	var cb = owner._character_base
	if cb == null:
		return false
	if not cb.has_method("consume_fire"):
		return false
	return cb.consume_fire()


func _get_burst_damage_mult() -> float:
	if owner == null:
		return 1.3
	if not "_character_base" in owner:
		return 1.3
	var cb = owner._character_base
	if cb == null:
		return 1.3
	if cb.has_method("get_fire_damage_mult"):
		return cb.get_fire_damage_mult()
	return 1.3


func _get_burst_range_mult() -> float:
	if owner == null:
		return 1.5
	if not "_character_base" in owner:
		return 1.5
	var cb = owner._character_base
	if cb == null:
		return 1.5
	if cb.has_method("get_fire_range_mult"):
		return cb.get_fire_range_mult()
	return 1.5


func _get_projectile_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var parent := get_parent()
	if parent != null and parent.get_parent() != null:
		return parent.get_parent()
	return self
