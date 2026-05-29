class_name SanJianDaoWeapon
extends WeaponBase

## 三尖两刃刀 W301（杨戬初始武器）
##
## Lv1: 扇形 90° 三段斩，间隔 0.15s，击退 40
## Lv2: 扇形 110°，第三段伤害 ×1.3
## Lv3: 四段，第四段 AOE 半径 40
## Lv4: 天眼一斩额外溅射（范围 80，溅射 50%）
##
## 天眼一斩：
##   消耗天眼槽 → 小怪即死(99999)，精英/Boss ×4 伤害
##   来自 CharacterBase 子类 YangJian 的 consume_heaven_eye()
##
## damage 18→30, cooldown 2.0→1.8

@export var level: int = 1: set = _apply_level

# 等级派生参数
var _arc_deg: float = 90.0
var _slash_count: int = 3
var _knockback_force: float = 40.0
var _third_slash_mult: float = 1.0
var _aoe_enabled: bool = false
var _aoe_radius: float = 40.0
var _heaveneye_splash_enabled: bool = false
var _heaveneye_splash_radius: float = 80.0
var _heaveneye_splash_pct: float = 0.5

# 多段斩内部状态
var _slash_timer: float = 0.0
var _slash_phase: int = 0       # 当前段序号（0 = 未激活）
var _slash_total: int = 0       # 本次攻击总段数
var _pending_is_eye: bool = false  # 本次是否为天眼一斩
var _slash_interval: float = 0.15


func _ready() -> void:
	if damage <= 0.0:
		damage = 18.0
	if cooldown <= 0.0:
		cooldown = 2.0
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			damage = 18.0
			cooldown = 2.0
			_arc_deg = 90.0
			_slash_count = 3
			_knockback_force = 40.0
			_third_slash_mult = 1.0
			_aoe_enabled = false
			_heaveneye_splash_enabled = false
		2:
			damage = 22.0
			cooldown = 1.9
			_arc_deg = 110.0
			_slash_count = 3
			_knockback_force = 40.0
			_third_slash_mult = 1.3
			_aoe_enabled = false
			_heaveneye_splash_enabled = false
		3:
			damage = 26.0
			cooldown = 1.85
			_arc_deg = 110.0
			_slash_count = 4
			_knockback_force = 40.0
			_third_slash_mult = 1.3
			_aoe_enabled = true
			_aoe_radius = 40.0
			_heaveneye_splash_enabled = false
		4:
			damage = 30.0
			cooldown = 1.8
			_arc_deg = 110.0
			_slash_count = 4
			_knockback_force = 40.0
			_third_slash_mult = 1.3
			_aoe_enabled = true
			_aoe_radius = 40.0
			_heaveneye_splash_enabled = true
			_heaveneye_splash_radius = 80.0
			_heaveneye_splash_pct = 0.5


## WeaponBase._process 冷却门控后调用
func _try_attack() -> bool:
	if _slash_phase > 0:
		# 上一次多段斩尚未完成（理论上不发生，冷却已保证）
		return false
	# 查询天眼一斩
	_pending_is_eye = _check_heaven_eye()
	# 启动多段斩序列
	_slash_phase = 1
	_slash_total = _slash_count
	_slash_timer = 0.0
	_do_slash(_slash_phase)
	return true


## override _process：在 WeaponBase 冷却逻辑之外，额外驱动多段斩后续段
func _process(delta: float) -> void:
	# 执行多段斩后续段
	if _slash_phase > 0 and _slash_phase < _slash_total:
		_slash_timer += delta
		if _slash_timer >= _slash_interval:
			_slash_timer = 0.0
			_slash_phase += 1
			_do_slash(_slash_phase)
			if _slash_phase >= _slash_total:
				_slash_phase = 0
	elif _slash_phase >= _slash_total and _slash_total > 0:
		_slash_phase = 0
	# WeaponBase 冷却逻辑
	super._process(delta)


## 执行第 phase 段斩击（1-indexed）
func _do_slash(phase: int) -> void:
	var facing := _get_facing()
	var half_arc_cos := cos(deg_to_rad(_arc_deg * 0.5))
	var radius_sq := attack_range * attack_range

	# 最后一段（Lv3+ 第4段）启用 AOE
	var is_final_slash := (phase == _slash_total)
	# 第三段（及以上）伤害倍率
	var phase_mult := _third_slash_mult if phase >= 3 else 1.0

	var hit_targets: Array[Node2D] = []

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var to_enemy: Vector2 = enemy_node.global_position - global_position
		if to_enemy.length_squared() > radius_sq:
			continue
		var dir_to_enemy := to_enemy.normalized()
		if dir_to_enemy.dot(facing) < half_arc_cos:
			continue
		hit_targets.append(enemy_node)

	for target in hit_targets:
		_apply_hit(target, phase_mult, is_final_slash)

	# Lv3+ 最后一段：以武器位置为中心的额外 AOE（已在扇形外的敌人）
	if _aoe_enabled and is_final_slash:
		var aoe_sq := _aoe_radius * _aoe_radius
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			if not enemy is Node2D:
				continue
			var enemy_node := enemy as Node2D
			if hit_targets.has(enemy_node):
				continue  # 已在扇形中命中，不重复
			if global_position.distance_squared_to(enemy_node.global_position) > aoe_sq:
				continue
			_apply_hit(enemy_node, phase_mult, false)


## 对单个目标应用伤害 + 击退（含天眼一斩判断）
func _apply_hit(target: Node2D, phase_mult: float, is_final: bool) -> void:
	if not target.has_method("take_damage"):
		return

	if _pending_is_eye:
		# 天眼一斩：检测是否为精英/Boss
		var is_elite: bool = (target.get("is_elite") == true) or (target.get("is_boss") == true)
		if is_elite:
			target.take_damage(_get_damage() * 4.0 * phase_mult)
		else:
			target.take_damage(99999.0)
		# Lv4：天眼溅射（范围内其他敌人受伤）
		if _heaveneye_splash_enabled:
			_do_heaveneye_splash(target)
	else:
		target.take_damage(_get_damage() * phase_mult)

	# 击退（duck typing）
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length_squared() > 0.001 and _knockback_force > 0.0:
		target.global_position += to_target.normalized() * _knockback_force


## 天眼溅射：对武器附近范围内其他敌人造成 50% 伤害
func _do_heaveneye_splash(origin: Node2D) -> void:
	var splash_sq := _heaveneye_splash_radius * _heaveneye_splash_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == origin:
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > splash_sq:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(_get_damage() * _heaveneye_splash_pct)


## 获取玩家朝向（owner 是 Player 节点）
func _get_facing() -> Vector2:
	if owner != null and "facing" in owner:
		var f: Vector2 = owner.facing
		if f.length_squared() > 0.001:
			return f.normalized()
	# 无朝向信息时找最近敌人方向
	var nearest := _find_nearest_enemy_dir()
	if nearest != Vector2.ZERO:
		return nearest
	return Vector2.RIGHT


## 找最近敌人方向（无 facing 时备用）
func _find_nearest_enemy_dir() -> Vector2:
	var nearest_dist_sq := INF
	var nearest_dir := Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var dist_sq := global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_dir = (enemy_node.global_position - global_position).normalized()
	return nearest_dir


## 向 YangJian 角色基类查询并消耗天眼槽
## owner 是 Player 节点，player._character_base 是 YangJian 实例
func _check_heaven_eye() -> bool:
	if owner == null:
		return false
	if not "_character_base" in owner:
		return false
	var cb = owner._character_base
	if cb == null:
		return false
	if not cb.has_method("consume_heaven_eye"):
		return false
	return cb.consume_heaven_eye()
