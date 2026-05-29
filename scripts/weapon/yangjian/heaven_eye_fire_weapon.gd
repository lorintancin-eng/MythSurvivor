class_name HeavenEyeFireWeapon
extends WeaponBase

## 天眼真火 W303（杨戬升级解锁武器，等级>=3 出现在升级池）
##
## 全屏扫描最低血量敌人，激光锁定连续多段伤害。
##
## Lv1: 最低血量 1 目标，激光 10 段，总伤 25，cd 8.0s
## Lv2: 总伤 35（+10），锁 2 目标，cd 7.5s
## Lv3: 激光 15 段（+5 段），总伤 40，cd 7.0s
## Lv4: 锁定精英/Boss 时伤害 ×2，总伤 45，cd 6.5s
##
## 视觉：MVP 版本——伤害生效，无激光线视觉效果（TODO: Line2D 激光 v0.7）

@export var level: int = 1: set = _apply_level

# 等级派生参数
var _target_count: int = 1
var _hit_count: int = 10
var _total_damage: float = 25.0
var _elite_boss_mult: float = 1.0

# 内部多段攻击状态
var _active_targets: Array[Node2D] = []
var _remaining_hits: int = 0
var _hit_interval: float = 0.1
var _hit_timer: float = 0.0
var _damage_per_hit: float = 0.0
var _is_attacking: bool = false


func _ready() -> void:
	if damage <= 0.0:
		damage = 25.0
	if cooldown <= 0.0:
		cooldown = 8.0
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_target_count = 1
			_hit_count = 10
			_total_damage = 25.0
			cooldown = 8.0
			_elite_boss_mult = 1.0
		2:
			_target_count = 2
			_hit_count = 10
			_total_damage = 35.0
			cooldown = 7.5
			_elite_boss_mult = 1.0
		3:
			_target_count = 2
			_hit_count = 15
			_total_damage = 40.0
			cooldown = 7.0
			_elite_boss_mult = 1.0
		4:
			_target_count = 2
			_hit_count = 15
			_total_damage = 45.0
			cooldown = 6.5
			_elite_boss_mult = 2.0


## WeaponBase._process 冷却门控后触发
func _try_attack() -> bool:
	if _is_attacking:
		return false

	# 全屏扫描，按当前血量升序排列（最低血量优先）
	var enemies: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node is Node2D:
			enemies.append(node as Node2D)

	if enemies.is_empty():
		return false

	# 按 current_hp 升序排（最低血量优先），duck typing
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var hp_a: float = a.get("current_hp") if "current_hp" in a else INF
		var hp_b: float = b.get("current_hp") if "current_hp" in b else INF
		return hp_a < hp_b
	)

	# 取前 _target_count 个
	_active_targets.clear()
	var pick_count := mini(_target_count, enemies.size())
	for i in range(pick_count):
		_active_targets.append(enemies[i])

	# 计算每段伤害
	_damage_per_hit = _total_damage / float(_hit_count)
	_remaining_hits = _hit_count
	_hit_timer = 0.0
	_is_attacking = true

	# 立即施加第一段
	_apply_hit_to_targets()

	return true


## override _process：在 WeaponBase 冷却之外额外驱动分段伤害
func _process(delta: float) -> void:
	if _is_attacking and _remaining_hits > 0:
		_hit_timer += delta
		if _hit_timer >= _hit_interval:
			_hit_timer = 0.0
			_apply_hit_to_targets()
		if _remaining_hits <= 0:
			_is_attacking = false
			_active_targets.clear()

	# WeaponBase 冷却逻辑
	super._process(delta)


## 对所有锁定目标施加一段伤害
func _apply_hit_to_targets() -> void:
	if _remaining_hits <= 0:
		return
	_remaining_hits -= 1

	for target in _active_targets:
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		if not target.has_method("take_damage"):
			continue

		var dmg := _damage_per_hit
		# Lv4：精英/Boss 伤害 ×2
		if _elite_boss_mult > 1.0:
			var is_elite: bool = (target.get("is_elite") == true) or (target.get("is_boss") == true)
			if is_elite:
				dmg *= _elite_boss_mult

		target.take_damage(dmg)
