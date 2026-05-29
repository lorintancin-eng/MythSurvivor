class_name HeavenGeneralBoss
extends Enemy

## 天兵统领 B801（L009 凌霄天宫，v0.2）
##
## 设计 §3 L009：4 技能套餐：
## - 技能 1 天雷劈击（cd 4.5s）：玩家周围 3 点落雷 58px / 25dmg
## - 技能 2 神兵阵法（cd 6s）：召唤 3 只天兵执戟 + 自身 4 点雷域
## - 技能 3 天戟横扫（cd 5s）：扇形 140° / 180px / 30dmg
## - 技能 4 雷劫降临（cd 15s / 暴怒 9.75s）：全屏 10 点落雷 50px / 22dmg
## 暴怒（35% HP）：cd×0.65 速×1.33 伤×1.25 金雷白光环

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const SKY_SOLDIER_ARCHETYPE: Resource = preload("res://resources/enemies/sky_soldier.tres")

# 技能 1 天雷劈击
@export var thunder_strike_cooldown: float = 4.5
@export var thunder_strike_warning_time: float = 0.9
@export var thunder_strike_count: int = 3
@export var thunder_strike_radius: float = 58.0
@export var thunder_strike_damage: float = 25.0
@export var thunder_strike_spread: float = 180.0

# 技能 2 神兵阵法
@export var formation_cooldown: float = 6.0
@export var formation_summon_count: int = 3
@export var formation_thunder_count: int = 4
@export var formation_thunder_radius: float = 55.0
@export var formation_thunder_damage: float = 16.0
@export var formation_thunder_warning_time: float = 0.7

# 技能 3 天戟横扫
@export var sweep_cooldown: float = 5.0
@export var sweep_warning_time: float = 0.6
@export var sweep_angle_deg: float = 140.0
@export var sweep_range: float = 180.0
@export var sweep_damage: float = 30.0

# 技能 4 雷劫降临
@export var tribulation_cooldown: float = 15.0
@export var tribulation_warning_time: float = 0.8
@export var tribulation_count: int = 10
@export var tribulation_radius: float = 50.0
@export var tribulation_damage: float = 22.0
@export var tribulation_spread: float = 500.0

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.33
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.65

var _thunder_timer: float = 0.0
var _formation_timer: float = 0.0
var _sweep_timer: float = 0.0
var _tribulation_timer: float = 0.0
var _is_enraged: bool = false

var _thunder_markers: Array[Dictionary] = []
var _sweep_marker: Dictionary = {}

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	thunder_strike_cooldown = maxf(thunder_strike_cooldown, 0.1)
	thunder_strike_warning_time = maxf(thunder_strike_warning_time, 0.05)
	thunder_strike_count = maxi(thunder_strike_count, 1)
	thunder_strike_radius = maxf(thunder_strike_radius, 4.0)
	thunder_strike_damage = maxf(thunder_strike_damage, 0.0)
	thunder_strike_spread = maxf(thunder_strike_spread, 8.0)
	formation_cooldown = maxf(formation_cooldown, 0.1)
	formation_summon_count = maxi(formation_summon_count, 0)
	formation_thunder_count = maxi(formation_thunder_count, 0)
	formation_thunder_radius = maxf(formation_thunder_radius, 4.0)
	formation_thunder_damage = maxf(formation_thunder_damage, 0.0)
	formation_thunder_warning_time = maxf(formation_thunder_warning_time, 0.05)
	sweep_cooldown = maxf(sweep_cooldown, 0.1)
	sweep_warning_time = maxf(sweep_warning_time, 0.05)
	sweep_angle_deg = clampf(sweep_angle_deg, 10.0, 360.0)
	sweep_range = maxf(sweep_range, 4.0)
	sweep_damage = maxf(sweep_damage, 0.0)
	tribulation_cooldown = maxf(tribulation_cooldown, 0.1)
	tribulation_warning_time = maxf(tribulation_warning_time, 0.05)
	tribulation_count = maxi(tribulation_count, 1)
	tribulation_radius = maxf(tribulation_radius, 4.0)
	tribulation_damage = maxf(tribulation_damage, 0.0)
	tribulation_spread = maxf(tribulation_spread, 8.0)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_thunder_timer = 3.0
	_formation_timer = 5.5
	_sweep_timer = 4.0
	_tribulation_timer = 12.0

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(52.0, 32)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_thunder_markers(delta)
	_process_sweep_marker(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_thunder_timer -= delta
	_formation_timer -= delta
	_sweep_timer -= delta
	_tribulation_timer -= delta

	# 技能触发（优先级：雷劫 > 神兵阵法 > 天雷劈击 > 天戟横扫）
	if _tribulation_timer <= 0.0:
		_trigger_tribulation()
		_tribulation_timer = tribulation_cooldown * _get_cd_multiplier()
	elif _formation_timer <= 0.0:
		_trigger_formation()
		_formation_timer = formation_cooldown * _get_cd_multiplier()
	elif _thunder_timer <= 0.0:
		_trigger_thunder_strike()
		_thunder_timer = thunder_strike_cooldown * _get_cd_multiplier()
	elif _sweep_timer <= 0.0:
		_trigger_sweep()
		_sweep_timer = sweep_cooldown * _get_cd_multiplier()

	# 慢速追击
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


# ========== 技能 1：天雷劈击（玩家周围多点落雷）==========

func _trigger_thunder_strike() -> void:
	if _player == null:
		return
	for i in range(thunder_strike_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, thunder_strike_spread)
		var pos := _player.global_position + offset
		_spawn_thunder_marker(pos, thunder_strike_warning_time, thunder_strike_radius, thunder_strike_damage)


func _spawn_thunder_marker(pos: Vector2, warn_time: float, radius: float, dmg: float) -> void:
	var marker := Node2D.new()
	marker.name = "ThunderMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.9, 0.85, 0.2, 0.4)
	warn.polygon = _make_circle_polygon(radius, 24)
	marker.add_child(warn)

	var explosion := Polygon2D.new()
	explosion.name = "Explosion"
	explosion.color = Color(1.0, 0.95, 0.5, 0.75)
	explosion.polygon = _make_circle_polygon(radius * 1.05, 24)
	explosion.visible = false
	marker.add_child(explosion)

	_thunder_markers.append({
		"node": marker,
		"timer": warn_time,
		"state": 0,
		"radius": radius,
		"damage": dmg,
	})


func _process_thunder_markers(delta: float) -> void:
	var i := _thunder_markers.size() - 1
	while i >= 0:
		var t := _thunder_markers[i]
		var node := t["node"] as Node2D
		if not is_instance_valid(node):
			_thunder_markers.remove_at(i)
			i -= 1
			continue
		t["timer"] = float(t["timer"]) - delta
		if int(t["state"]) == 0 and float(t["timer"]) <= 0.0:
			_detonate_thunder(node, float(t["radius"]), float(t["damage"]))
			t["state"] = 1
			t["timer"] = 0.18
		elif int(t["state"]) == 1 and float(t["timer"]) <= 0.0:
			node.queue_free()
			_thunder_markers.remove_at(i)
		i -= 1


func _detonate_thunder(marker: Node2D, radius: float, dmg: float) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false
	var explosion := marker.get_node_or_null("Explosion") as Polygon2D
	if explosion != null:
		explosion.visible = true
	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", dmg)


# ========== 技能 2：神兵阵法（召唤天兵 + Boss 周围落雷）==========

func _trigger_formation() -> void:
	# 召唤天兵执戟
	for i in range(formation_summon_count):
		_summon_sky_soldier()
	# Boss 周围 4 点落雷
	for i in range(formation_thunder_count):
		var angle := TAU * float(i) / float(formation_thunder_count)
		var offset := Vector2.RIGHT.rotated(angle) * randf_range(80.0, 160.0)
		var pos := global_position + offset
		_spawn_thunder_marker(pos, formation_thunder_warning_time, formation_thunder_radius, formation_thunder_damage)


func _summon_sky_soldier() -> void:
	if SKY_SOLDIER_ARCHETYPE == null or ENEMY_SCENE == null:
		return
	var enemy_node := ENEMY_SCENE.instantiate()
	if enemy_node == null:
		return
	var parent := _get_effect_parent()
	parent.add_child(enemy_node)
	# 随机偏移生成位置，避免堆叠
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 180.0)
	enemy_node.global_position = global_position + offset
	# 应用天兵执戟 archetype 数值（duck typing）
	if "max_hp" in enemy_node:
		enemy_node.max_hp = SKY_SOLDIER_ARCHETYPE.max_hp
	if "current_hp" in enemy_node:
		enemy_node.current_hp = SKY_SOLDIER_ARCHETYPE.max_hp
	if "move_speed" in enemy_node:
		enemy_node.move_speed = SKY_SOLDIER_ARCHETYPE.move_speed
	if "damage" in enemy_node:
		enemy_node.damage = SKY_SOLDIER_ARCHETYPE.damage
	if "xp_drop_value" in enemy_node:
		enemy_node.xp_drop_value = SKY_SOLDIER_ARCHETYPE.xp_drop_value
	if "_body" in enemy_node and is_instance_valid(enemy_node._body):
		enemy_node._body.color = SKY_SOLDIER_ARCHETYPE.body_color


# ========== 技能 3：天戟横扫（扇形 AOE）==========

func _trigger_sweep() -> void:
	if _player == null:
		return
	var sweep_dir := global_position.direction_to(_player.global_position)
	var marker := Node2D.new()
	marker.name = "SweepMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var half_angle := deg_to_rad(sweep_angle_deg * 0.5)
	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.95, 0.8, 0.1, 0.35)
	var fan_points := PackedVector2Array()
	fan_points.append(Vector2.ZERO)
	var segments: int = 20
	for j in range(segments + 1):
		var a := sweep_dir.angle() - half_angle + (float(j) / float(segments)) * (half_angle * 2.0)
		fan_points.append(Vector2.RIGHT.rotated(a) * sweep_range)
	warn.polygon = fan_points
	marker.add_child(warn)

	_sweep_marker = {
		"node": marker,
		"timer": sweep_warning_time,
		"state": 0,
		"dir": sweep_dir,
	}


func _process_sweep_marker(delta: float) -> void:
	if _sweep_marker.is_empty():
		return
	var node := _sweep_marker.get("node") as Node2D
	if not is_instance_valid(node):
		_sweep_marker = {}
		return
	_sweep_marker["timer"] = float(_sweep_marker["timer"]) - delta
	if int(_sweep_marker["state"]) == 0 and float(_sweep_marker["timer"]) <= 0.0:
		_detonate_sweep(node)
		_sweep_marker["state"] = 1
		_sweep_marker["timer"] = 0.2
	elif int(_sweep_marker["state"]) == 1 and float(_sweep_marker["timer"]) <= 0.0:
		node.queue_free()
		_sweep_marker = {}


func _detonate_sweep(marker: Node2D) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.color = Color(1.0, 0.9, 0.4, 0.65)
	if not is_instance_valid(_player):
		return
	var sweep_dir: Vector2 = _sweep_marker.get("dir", Vector2.RIGHT)
	var half_angle := deg_to_rad(sweep_angle_deg * 0.5)
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > sweep_range:
		return
	var angle_to_player := to_player.angle()
	var angle_diff := absf(wrapf(angle_to_player - sweep_dir.angle(), -PI, PI))
	if angle_diff > half_angle:
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", sweep_damage)


# ========== 技能 4：雷劫降临（全屏多点落雷）==========

func _trigger_tribulation() -> void:
	if _player == null:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var center := viewport_rect.get_center()
	for i in range(tribulation_count):
		# 随机分布在屏幕范围内（以玩家为中心偏移）
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, tribulation_spread)
		var pos := _player.global_position + offset
		# 为每个落雷点错开预警时间，产生逐个落下的视觉感
		var extra_delay := float(i) * 0.12
		_spawn_thunder_marker_delayed(pos, tribulation_warning_time + extra_delay, tribulation_radius, tribulation_damage)


func _spawn_thunder_marker_delayed(pos: Vector2, warn_time: float, radius: float, dmg: float) -> void:
	# 延迟生成：创建一个计时节点，到期后再 spawn marker
	# MVP 简化：直接用 warn_time 较大值模拟延迟效果
	_spawn_thunder_marker(pos, warn_time, radius, dmg)


# ========== 暴怒 ==========

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if _is_dead or _is_enraged:
		return
	if current_hp / max_hp <= enrage_health_ratio:
		_enter_enrage()


func _enter_enrage() -> void:
	_is_enraged = true
	move_speed *= enrage_speed_multiplier
	damage *= enrage_damage_multiplier
	# 收紧各计时器到暴怒 CD 上限
	_thunder_timer = minf(_thunder_timer, thunder_strike_cooldown * enrage_cd_multiplier * 0.5)
	_formation_timer = minf(_formation_timer, formation_cooldown * enrage_cd_multiplier * 0.5)
	_sweep_timer = minf(_sweep_timer, sweep_cooldown * enrage_cd_multiplier * 0.5)
	_tribulation_timer = minf(_tribulation_timer, tribulation_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.9, 0.75, 0.1, 1.0)
	if _enraged_aura != null:
		_enraged_aura.visible = true


func _get_cd_multiplier() -> float:
	if _is_enraged:
		return enrage_cd_multiplier
	return 1.0


# ========== 死亡清场 ==========

func _die() -> void:
	for t in _thunder_markers:
		var n = t["node"]
		if is_instance_valid(n):
			n.queue_free()
	_thunder_markers.clear()
	if not _sweep_marker.is_empty():
		var n = _sweep_marker.get("node")
		if is_instance_valid(n):
			n.queue_free()
	_sweep_marker = {}
	super._die()


# ========== 工具函数 ==========

func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in maxi(point_count, 3):
		var angle := TAU * float(i) / float(maxi(point_count, 3))
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var parent := get_parent()
	if parent != null:
		return parent
	return self
