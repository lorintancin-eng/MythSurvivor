class_name HunTianLingWeapon
extends WeaponBase

## 混天绫 W202（哪吒升级解锁武器）
##
## Lv1: 半径 80 环形 + 减速 40%/1.5s + DoT 6/s
## Lv2: 半径 100，减速 50%/2.0s
## Lv3: 命中束缚 0.5s（敌人完全停止）
## Lv4: 半径 120，DoT +4/s，束缚 +0.3s
## damage 6→12, cooldown 3.0→2.4
##
## 减速用 duck typing：直接写 enemy.move_speed，Timer 到期还原（不改 enemy.gd）
## 三昧真火爆发：consume_fire 时本次范围 ×1.5

@export var level: int = 1: set = _apply_level
@export var radius: float = 80.0
@export var slow_mult: float = 0.6        # 0.6 = 剩余 60%，即减速 40%
@export var slow_duration: float = 1.5
@export var dot_dps: float = 6.0          # 持续伤害每秒
@export var dot_ticks: int = 3            # DoT 分 N 段打（tick 间隔 = slow_duration/ticks）
@export var bind_duration: float = 0.0    # Lv3+ 束缚时长（0 = 不束缚）

# 命中集合：避免同次攻击对同一敌人多次减速
var _hit_this_attack: Array = []


func _ready() -> void:
	if damage <= 0.0:
		damage = 6.0
	if cooldown <= 0.0:
		cooldown = 3.0
	_apply_level(level)


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			damage = 6.0
			cooldown = 3.0
			radius = 80.0
			slow_mult = 0.6
			slow_duration = 1.5
			dot_dps = 6.0
			dot_ticks = 3
			bind_duration = 0.0
		2:
			damage = 8.0
			cooldown = 2.8
			radius = 100.0
			slow_mult = 0.5
			slow_duration = 2.0
			dot_dps = 6.0
			dot_ticks = 3
			bind_duration = 0.0
		3:
			damage = 10.0
			cooldown = 2.6
			radius = 100.0
			slow_mult = 0.5
			slow_duration = 2.0
			dot_dps = 6.0
			dot_ticks = 3
			bind_duration = 0.5
		4:
			damage = 12.0
			cooldown = 2.4
			radius = 120.0
			slow_mult = 0.5
			slow_duration = 2.0
			dot_dps = 10.0
			dot_ticks = 3
			bind_duration = 0.8


## WeaponBase 攻击触发
func _try_attack() -> bool:
	# 查询三昧真火爆发
	var burst_radius_mult := 1.0
	if _check_fire_burst():
		burst_radius_mult = _get_fire_range_mult()

	var effective_radius := radius * burst_radius_mult
	_hit_this_attack.clear()
	var did_hit := false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > effective_radius * effective_radius:
			continue

		# 直接伤害
		enemy_node.call("take_damage", _get_damage())
		did_hit = true
		_hit_this_attack.append(enemy_node)

		# 减速 + DoT（异步，不阻塞攻击循环）
		_apply_slow_and_dot(enemy_node)

	return did_hit


## 对单个敌人施加减速 + DoT
func _apply_slow_and_dot(enemy: Node2D) -> void:
	# Duck typing 减速：写 move_speed 字段；若没有该字段则跳过
	if not "move_speed" in enemy:
		return

	var original_speed: float = enemy.get("move_speed")

	# Lv3+ 束缚（完全停止）
	if bind_duration > 0.0:
		enemy.set("move_speed", 0.0)
		get_tree().create_timer(bind_duration).timeout.connect(
			func() -> void:
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
					# 束缚结束后进入减速
					enemy.set("move_speed", original_speed * slow_mult)
					_schedule_slow_restore(enemy, original_speed, slow_duration)
		)
	else:
		# 直接减速
		var current_speed: float = enemy.get("move_speed")
		# 若已减速则不叠加（比较是否已低于原速）
		if current_speed > original_speed * slow_mult:
			enemy.set("move_speed", original_speed * slow_mult)
		_schedule_slow_restore(enemy, original_speed, slow_duration)

	# DoT 分段伤害
	_apply_dot(enemy)


## Timer 到期后还原移速
func _schedule_slow_restore(enemy: Node2D, original_speed: float, duration: float) -> void:
	get_tree().create_timer(duration).timeout.connect(
		func() -> void:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				enemy.set("move_speed", original_speed)
	)


## DoT：分 dot_ticks 次，间隔 slow_duration/dot_ticks 秒，每次造成 dot_dps*(slow_duration/dot_ticks) 伤害
func _apply_dot(enemy: Node2D) -> void:
	var ticks := maxi(dot_ticks, 1)
	var tick_interval := slow_duration / float(ticks)
	var tick_damage := dot_dps * tick_interval

	for i in range(ticks):
		var delay := tick_interval * float(i + 1)
		get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
					enemy.call("take_damage", tick_damage)
		)


## 向 Nezha 角色查询并消耗三昧真火
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


func _get_fire_range_mult() -> float:
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
