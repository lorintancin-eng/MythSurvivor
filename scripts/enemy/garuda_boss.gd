class_name GarudaBoss
extends Enemy

## 大鹏金翅鸟 B901（L010 十·灵山雷音，终局Boss）
##
## 4 技能套餐（全机制融合）：
## - 技能 1 金翅横扫（cd 3.5s）：扇形 140°/200px/35dmg（最频繁）
## - 技能 2 天雷金火（cd 6s）：玩家周围 5 点金火雷 60px/28dmg + 落点 BURN 区 3s
## - 技能 3 大鹏展翼（cd 10s）：全屏 PUSH 1.5s + 6 点落石
## - 技能 4 金翅大日（cd 18s / 暴怒 11.7s）：全屏 SNARE 2s + 12 点落雷 + 落点 BURN+雷域双区 4s
## 暴怒（40% HP）：cd×0.60 速×1.33=100 伤×1.25=47
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L010

const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

# 技能 1 金翅横扫
@export var sweep_cooldown: float = 3.5
@export var sweep_warning_time: float = 0.5
@export var sweep_arc_degrees: float = 140.0
@export var sweep_radius: float = 200.0
@export var sweep_damage: float = 35.0

# 技能 2 天雷金火（金火雷落点 + BURN 区）
@export var thunder_fire_cooldown: float = 6.0
@export var thunder_fire_count: int = 5
@export var thunder_fire_spread: float = 220.0
@export var thunder_fire_warning_time: float = 0.65
@export var thunder_fire_radius: float = 60.0
@export var thunder_fire_damage: float = 28.0
@export var thunder_fire_burn_radius: float = 50.0
@export var thunder_fire_burn_duration: float = 3.0
@export var thunder_fire_burn_dps: float = 6.0

# 技能 3 大鹏展翼（全屏 PUSH + 落石）
@export var wing_cooldown: float = 10.0
@export var wing_push_strength: float = 300.0
@export var wing_push_duration: float = 1.5
@export var wing_rock_count: int = 6
@export var wing_rock_spread: float = 260.0
@export var wing_rock_warning_time: float = 0.8
@export var wing_rock_radius: float = 50.0
@export var wing_rock_damage: float = 20.0

# 技能 4 金翅大日（全屏 SNARE + 落雷 + 双区，终局最强）
@export var dairi_cooldown: float = 18.0
@export var dairi_enraged_cooldown: float = 11.7
@export var dairi_snare_duration: float = 2.0
@export var dairi_thunder_count: int = 12
@export var dairi_thunder_spread: float = 280.0
@export var dairi_thunder_warning_time: float = 1.0
@export var dairi_thunder_radius: float = 55.0
@export var dairi_thunder_damage: float = 22.0
@export var dairi_zone_burn_radius: float = 50.0
@export var dairi_zone_burn_duration: float = 4.0
@export var dairi_zone_burn_dps: float = 8.0

# 暴怒
@export var enrage_health_ratio: float = 0.40
@export var enrage_speed_multiplier: float = 1.33
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.60

var _sweep_timer: float = 0.0
var _thunder_fire_timer: float = 0.0
var _wing_timer: float = 0.0
var _dairi_timer: float = 0.0
var _is_enraged: bool = false
var _burst_markers: Array[Dictionary] = []

# SNARE 移除计时
var _snare_active: bool = false
var _snare_remove_timer: float = 0.0

# 展翼 PUSH 持续计时
var _push_active: bool = false
var _push_timer: float = 0.0

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	sweep_cooldown = maxf(sweep_cooldown, 0.1)
	thunder_fire_cooldown = maxf(thunder_fire_cooldown, 0.1)
	wing_cooldown = maxf(wing_cooldown, 0.1)
	dairi_cooldown = maxf(dairi_cooldown, 0.1)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_sweep_timer = 2.0
	_thunder_fire_timer = 4.5
	_wing_timer = 8.0
	_dairi_timer = 14.0

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(80.0, 32)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_cleanup_effects()
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_burst_markers(delta)
	_process_snare_timer(delta)
	_process_push_timer(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_process_skills(delta)

	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


# ========== 技能调度 ==========

func _process_skills(delta: float) -> void:
	_sweep_timer -= delta
	_thunder_fire_timer -= delta
	_wing_timer -= delta
	_dairi_timer -= delta

	# 技能触发优先级：金翅大日 > 大鹏展翼 > 天雷金火 > 金翅横扫
	if _dairi_timer <= 0.0:
		_trigger_dairi()
		var dcd: float = dairi_enraged_cooldown if _is_enraged else dairi_cooldown
		_dairi_timer = dcd * _get_cd_multiplier()
	elif _wing_timer <= 0.0:
		_trigger_wing()
		_wing_timer = wing_cooldown * _get_cd_multiplier()
	elif _thunder_fire_timer <= 0.0:
		_trigger_thunder_fire()
		_thunder_fire_timer = thunder_fire_cooldown * _get_cd_multiplier()
	elif _sweep_timer <= 0.0:
		_trigger_sweep()
		_sweep_timer = sweep_cooldown * _get_cd_multiplier()


# ========== 技能 1：金翅横扫（扇形 AOE，最频繁）==========

func _trigger_sweep() -> void:
	if _player == null:
		return
	var marker := Node2D.new()
	marker.name = "SweepMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var direction := global_position.direction_to(_player.global_position)
	var base_angle := direction.angle()

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.9, 0.7, 0.1, 0.38)
	warn.polygon = _make_arc_polygon(sweep_radius, sweep_arc_degrees, base_angle, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": sweep_warning_time,
		"state": 0,
		"type": "sweep",
		"base_angle": base_angle,
	})


func _detonate_sweep(marker: Node2D, base_angle: float) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.85, 0.2, 0.7)
	flash.polygon = _make_arc_polygon(sweep_radius * 1.05, sweep_arc_degrees, base_angle, 20)
	marker.add_child(flash)

	if is_instance_valid(_player):
		var diff := _player.global_position - marker.global_position
		var dist := diff.length()
		if dist <= sweep_radius:
			var player_angle := diff.angle()
			var half_arc := deg_to_rad(sweep_arc_degrees * 0.5)
			var angle_diff := absf(wrapf(player_angle - base_angle, -PI, PI))
			if angle_diff <= half_arc:
				if _player.has_method("take_damage"):
					_player.call("take_damage", sweep_damage)


# ========== 技能 2：天雷金火（5 点金火雷 + BURN 区）==========

func _trigger_thunder_fire() -> void:
	if _player == null:
		return
	for i in range(thunder_fire_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, thunder_fire_spread)
		var pos := _player.global_position + offset
		_spawn_thunder_marker(pos, thunder_fire_radius, thunder_fire_damage, thunder_fire_warning_time, true)


func _spawn_thunder_marker(pos: Vector2, radius: float, dmg: float, warn_time: float, spawn_burn: bool) -> void:
	var marker := Node2D.new()
	marker.name = "ThunderMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.9, 0.8, 0.15, 0.40)
	warn.polygon = _make_circle_polygon(radius, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": warn_time,
		"state": 0,
		"type": "thunder",
		"radius": radius,
		"damage": dmg,
		"spawn_burn": spawn_burn,
		"burn_radius": thunder_fire_burn_radius,
		"burn_duration": thunder_fire_burn_duration,
		"burn_dps": thunder_fire_burn_dps,
	})


func _detonate_thunder(marker: Node2D, t: Dictionary) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.9, 0.3, 0.65)
	flash.polygon = _make_circle_polygon(float(t["radius"]) * 1.05, 20)
	marker.add_child(flash)

	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= float(t["radius"]):
			if _player.has_method("take_damage"):
				_player.call("take_damage", float(t["damage"]))

	if bool(t["spawn_burn"]):
		_spawn_burn_at(marker.global_position, float(t["burn_radius"]), float(t["burn_duration"]), float(t["burn_dps"]))


# ========== 技能 3：大鹏展翼（全屏 PUSH + 6 点落石）==========

func _trigger_wing() -> void:
	if _player == null:
		return
	# 全屏 PUSH（持续推开玩家 wing_push_duration 秒）
	_push_active = true
	_push_timer = wing_push_duration
	# 生成 6 点落石
	for i in range(wing_rock_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, wing_rock_spread)
		var pos := _player.global_position + offset
		_spawn_rock_marker(pos, wing_rock_radius, wing_rock_damage, wing_rock_warning_time)


func _spawn_rock_marker(pos: Vector2, radius: float, dmg: float, warn_time: float) -> void:
	var marker := Node2D.new()
	marker.name = "RockMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.75, 0.65, 0.2, 0.42)
	warn.polygon = _make_circle_polygon(radius, 16)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": warn_time,
		"state": 0,
		"type": "rock",
		"radius": radius,
		"damage": dmg,
	})


func _detonate_rock(marker: Node2D, t: Dictionary) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.85, 0.75, 0.3, 0.6)
	flash.polygon = _make_circle_polygon(float(t["radius"]) * 1.05, 16)
	marker.add_child(flash)

	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= float(t["radius"]):
			if _player.has_method("take_damage"):
				_player.call("take_damage", float(t["damage"]))


func _process_push_timer(delta: float) -> void:
	if not _push_active:
		return
	_push_timer -= delta
	if _push_timer <= 0.0:
		_push_active = false
		return
	# 每帧持续推开玩家
	if is_instance_valid(_player) and _player.has_method("apply_water_push"):
		if _player.global_position.distance_to(global_position) > 5.0:
			var push_dir := (_player.global_position - global_position).normalized()
			_player.call("apply_water_push", push_dir * wing_push_strength * delta)


# ========== 技能 4：金翅大日（全屏 SNARE + 12 点落雷 + BURN+雷域双区）==========

func _trigger_dairi() -> void:
	if _player == null:
		return
	# 全屏 SNARE 2s
	_apply_snare_to_player()
	# 12 点落雷（落点各生成 BURN + 雷域双区）
	for i in range(dairi_thunder_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, dairi_thunder_spread)
		var pos := _player.global_position + offset
		_spawn_dairi_thunder_marker(pos)


func _spawn_dairi_thunder_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.name = "DairiThunderMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(1.0, 0.85, 0.1, 0.45)
	warn.polygon = _make_circle_polygon(dairi_thunder_radius, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": dairi_thunder_warning_time,
		"state": 0,
		"type": "dairi_thunder",
		"radius": dairi_thunder_radius,
		"damage": dairi_thunder_damage,
	})


func _detonate_dairi_thunder(marker: Node2D, t: Dictionary) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.95, 0.35, 0.7)
	flash.polygon = _make_circle_polygon(float(t["radius"]) * 1.05, 20)
	marker.add_child(flash)

	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= float(t["radius"]):
			if _player.has_method("take_damage"):
				_player.call("take_damage", float(t["damage"]))

	# 落点生成 BURN 区（金焰）
	_spawn_burn_at(marker.global_position, dairi_zone_burn_radius, dairi_zone_burn_duration, dairi_zone_burn_dps)
	# 落点生成 BURN 区再叠一个，颜色改为雷域（金黄），模拟雷域效果
	_spawn_thunder_zone_at(marker.global_position, dairi_zone_burn_radius * 0.85, dairi_zone_burn_duration)


func _apply_snare_to_player() -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("apply_terrain_effect"):
		_player.call("apply_terrain_effect", TerrainEffect.Type.SNARE, dairi_snare_duration)
	_snare_active = true
	_snare_remove_timer = dairi_snare_duration


func _process_snare_timer(delta: float) -> void:
	if not _snare_active:
		return
	_snare_remove_timer -= delta
	if _snare_remove_timer <= 0.0:
		_snare_active = false
		if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
			_player.call("remove_terrain_effect", TerrainEffect.Type.SNARE)


# ========== 通用地形效果生成 ==========

func _spawn_burn_at(pos: Vector2, radius: float, duration: float, dps: float) -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.BURN
	te.effect_radius = radius
	te.burn_dps = dps
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = pos
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(te.queue_free)


func _spawn_thunder_zone_at(pos: Vector2, radius: float, duration: float) -> void:
	## 雷域：复用 BURN 类型，但用金黄色（burn_color 由 TerrainEffect 决定，此处用小 BURN 叠效果）
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.BURN
	te.effect_radius = radius
	te.burn_dps = 8.0
	te.burn_color = Color(0.9, 0.8, 0.1, 0.45)
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = pos
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(te.queue_free)


# ========== 通用爆炸标记处理 ==========

func _process_burst_markers(delta: float) -> void:
	var i := _burst_markers.size() - 1
	while i >= 0:
		var t := _burst_markers[i]
		var node := t["node"] as Node2D
		if not is_instance_valid(node):
			_burst_markers.remove_at(i)
			i -= 1
			continue
		t["timer"] = float(t["timer"]) - delta
		if int(t["state"]) == 0 and float(t["timer"]) <= 0.0:
			var type: String = t["type"]
			match type:
				"sweep":
					_detonate_sweep(node, float(t["base_angle"]))
				"thunder":
					_detonate_thunder(node, t)
				"rock":
					_detonate_rock(node, t)
				"dairi_thunder":
					_detonate_dairi_thunder(node, t)
			t["state"] = 1
			t["timer"] = 0.18
		elif int(t["state"]) == 1 and float(t["timer"]) <= 0.0:
			node.queue_free()
			_burst_markers.remove_at(i)
		i -= 1


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
	sweep_damage *= enrage_damage_multiplier
	thunder_fire_damage *= enrage_damage_multiplier
	wing_rock_damage *= enrage_damage_multiplier
	dairi_thunder_damage *= enrage_damage_multiplier
	# 收紧各计时器到暴怒 CD 上限
	_sweep_timer = minf(_sweep_timer, sweep_cooldown * enrage_cd_multiplier * 0.5)
	_thunder_fire_timer = minf(_thunder_fire_timer, thunder_fire_cooldown * enrage_cd_multiplier * 0.5)
	_wing_timer = minf(_wing_timer, wing_cooldown * enrage_cd_multiplier * 0.5)
	_dairi_timer = minf(_dairi_timer, dairi_enraged_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.95, 0.4, 0.05, 1.0)
	if _enraged_aura != null:
		_enraged_aura.visible = true


func _get_cd_multiplier() -> float:
	return enrage_cd_multiplier if _is_enraged else 1.0


# ========== 死亡清场 ==========

func _die() -> void:
	_cleanup_effects()
	super._die()


func _cleanup_effects() -> void:
	for t in _burst_markers:
		var n = t["node"]
		if is_instance_valid(n):
			n.queue_free()
	_burst_markers.clear()
	# 移除残留 SNARE
	if _snare_active and is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.SNARE)
	_snare_active = false
	_push_active = false


# ========== 工具函数 ==========

func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in maxi(point_count, 3):
		var angle := TAU * float(i) / float(maxi(point_count, 3))
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _make_arc_polygon(radius: float, arc_degrees: float, base_angle: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	var n := maxi(point_count, 4)
	points.append(Vector2.ZERO)
	for i in range(n + 1):
		var t := float(i) / float(n)
		var angle := base_angle - half_arc + t * deg_to_rad(arc_degrees)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
