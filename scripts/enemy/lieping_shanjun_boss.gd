class_name LiepingShanjunBoss
extends Enemy

## 裂境山君 B201（L003 妖王，v0.6）
##
## 设计 §3：纯技能型 Boss（无召唤），4 技能套餐：
## - 技能 1 阵法陷阱（cd 4.5s，多点 AOE）
## - 技能 2 灵脉震击（cd 6s，线形伤害带）
## - 技能 4 蓝色光柱阵（cd 5s，玩家周围 4 点）
## - 技能 6 镇压（cd 12s，全屏减速）
## 暴怒（35% HP）：所有 cd ×0.65，移速 ×1.3，伤害 ×1.3，蓝紫光环

# 技能 1 阵法陷阱
@export var traps_cooldown: float = 4.5
@export var traps_warning_time: float = 1.0
@export var traps_count_min: int = 3
@export var traps_count_max: int = 5
@export var traps_radius: float = 52.0
@export var traps_damage: float = 14.0
@export var traps_spread: float = 200.0

# 技能 2 灵脉震击
@export var beam_cooldown: float = 6.0
@export var beam_warning_time: float = 0.8
@export var beam_width: float = 60.0
@export var beam_length: float = 360.0
@export var beam_damage: float = 20.0
@export var beam_linger_time: float = 0.25

# 技能 4 蓝色光柱阵
@export var pillars_cooldown: float = 5.0
@export var pillars_warning_time: float = 0.6
@export var pillars_count: int = 4
@export var pillars_damage: float = 10.0
@export var pillars_radius: float = 40.0
@export var pillars_spread_min: float = 80.0
@export var pillars_spread_max: float = 160.0

# 技能 6 镇压（全屏减速）
@export var suppress_cooldown: float = 12.0
@export var suppress_duration: float = 3.0

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.3
@export var enrage_damage_multiplier: float = 1.3
@export var enrage_cd_multiplier: float = 0.65

var _traps_timer: float = 0.0
var _beam_timer: float = 0.0
var _pillars_timer: float = 0.0
var _suppress_timer: float = 0.0
var _is_enraged: bool = false
var _trap_markers: Array[Dictionary] = []
var _pillar_markers: Array[Dictionary] = []
var _beam_marker: Node2D = null

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	traps_cooldown = maxf(traps_cooldown, 0.1)
	traps_warning_time = maxf(traps_warning_time, 0.05)
	traps_count_min = maxi(traps_count_min, 1)
	traps_count_max = maxi(traps_count_max, traps_count_min)
	traps_radius = maxf(traps_radius, 4.0)
	traps_damage = maxf(traps_damage, 0.0)
	traps_spread = maxf(traps_spread, 8.0)
	beam_cooldown = maxf(beam_cooldown, 0.1)
	beam_warning_time = maxf(beam_warning_time, 0.05)
	beam_width = maxf(beam_width, 4.0)
	beam_length = maxf(beam_length, 4.0)
	beam_damage = maxf(beam_damage, 0.0)
	beam_linger_time = maxf(beam_linger_time, 0.05)
	pillars_cooldown = maxf(pillars_cooldown, 0.1)
	pillars_warning_time = maxf(pillars_warning_time, 0.05)
	pillars_count = maxi(pillars_count, 1)
	pillars_damage = maxf(pillars_damage, 0.0)
	pillars_radius = maxf(pillars_radius, 4.0)
	pillars_spread_min = maxf(pillars_spread_min, 0.0)
	pillars_spread_max = maxf(pillars_spread_max, pillars_spread_min)
	suppress_cooldown = maxf(suppress_cooldown, 0.1)
	suppress_duration = maxf(suppress_duration, 0.1)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_traps_timer = 3.0
	_beam_timer = 5.0
	_pillars_timer = 4.0
	_suppress_timer = 10.0

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(44.0, 28)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_trap_markers(delta)
	_process_pillar_markers(delta)
	_process_beam_marker(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_traps_timer -= delta
	_beam_timer -= delta
	_pillars_timer -= delta
	_suppress_timer -= delta

	# 技能触发（优先级：suppress > beam > traps > pillars）
	if _suppress_timer <= 0.0:
		_trigger_suppress()
		_suppress_timer = suppress_cooldown * _get_cd_multiplier()
	elif _beam_timer <= 0.0:
		_trigger_beam()
		_beam_timer = beam_cooldown * _get_cd_multiplier()
	elif _traps_timer <= 0.0:
		_trigger_traps()
		_traps_timer = traps_cooldown * _get_cd_multiplier()
	elif _pillars_timer <= 0.0:
		_trigger_pillars()
		_pillars_timer = pillars_cooldown * _get_cd_multiplier()

	# 慢速追击
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


# ========== 技能 1：阵法陷阱（多点 AOE）==========

func _trigger_traps() -> void:
	if _player == null:
		return
	var count := randi_range(traps_count_min, traps_count_max)
	for i in range(count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, traps_spread)
		var pos := _player.global_position + offset
		var marker := _create_trap_marker(pos)
		_trap_markers.append({
			"node": marker,
			"timer": traps_warning_time,
			"state": 0,
		})


func _create_trap_marker(pos: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.name = "LiepingTrapMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.3, 0.5, 0.9, 0.35)
	warn.polygon = _make_circle_polygon(traps_radius, 24)
	marker.add_child(warn)

	var explosion := Polygon2D.new()
	explosion.name = "Explosion"
	explosion.color = Color(0.5, 0.8, 1.0, 0.6)
	explosion.polygon = _make_circle_polygon(traps_radius * 1.05, 24)
	explosion.visible = false
	marker.add_child(explosion)

	return marker


func _process_trap_markers(delta: float) -> void:
	var i := _trap_markers.size() - 1
	while i >= 0:
		var t := _trap_markers[i]
		var node := t["node"] as Node2D
		if not is_instance_valid(node):
			_trap_markers.remove_at(i)
			i -= 1
			continue
		t["timer"] = float(t["timer"]) - delta
		if int(t["state"]) == 0 and float(t["timer"]) <= 0.0:
			_detonate_trap(node)
			t["state"] = 1
			t["timer"] = 0.18
		elif int(t["state"]) == 1 and float(t["timer"]) <= 0.0:
			node.queue_free()
			_trap_markers.remove_at(i)
		i -= 1


func _detonate_trap(marker: Node2D) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false
	var explosion := marker.get_node_or_null("Explosion") as Polygon2D
	if explosion != null:
		explosion.visible = true
	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= traps_radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", traps_damage)


# ========== 技能 2：灵脉震击（线形）==========

func _trigger_beam() -> void:
	if _player == null:
		return
	var direction := global_position.direction_to(_player.global_position)
	_beam_marker = _create_beam_marker(direction)


func _create_beam_marker(direction: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.name = "LiepingBeamMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position
	marker.rotation = direction.angle()

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.4, 0.6, 0.95, 0.4)
	warn.polygon = PackedVector2Array([
		Vector2(0.0, -beam_width * 0.5),
		Vector2(beam_length, -beam_width * 0.5),
		Vector2(beam_length, beam_width * 0.5),
		Vector2(0.0, beam_width * 0.5),
	])
	marker.add_child(warn)

	marker.set_meta("timer", beam_warning_time)
	marker.set_meta("state", 0)
	marker.set_meta("direction", direction)
	return marker


func _process_beam_marker(delta: float) -> void:
	if _beam_marker == null or not is_instance_valid(_beam_marker):
		_beam_marker = null
		return
	var t: float = _beam_marker.get_meta("timer")
	t -= delta
	var state: int = _beam_marker.get_meta("state")
	if state == 0 and t <= 0.0:
		_detonate_beam()
		_beam_marker.set_meta("state", 1)
		_beam_marker.set_meta("timer", beam_linger_time)
	elif state == 1 and t <= 0.0:
		_beam_marker.queue_free()
		_beam_marker = null
		return
	if _beam_marker != null:
		_beam_marker.set_meta("timer", t)


func _detonate_beam() -> void:
	if _beam_marker == null or not is_instance_valid(_beam_marker):
		return
	var warn := _beam_marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.color = Color(0.6, 0.85, 1.0, 0.7)
	var direction: Vector2 = _beam_marker.get_meta("direction")
	if not is_instance_valid(_player):
		return
	var to_player := _player.global_position - _beam_marker.global_position
	var along := to_player.dot(direction)
	if along < 0.0 or along > beam_length:
		return
	var perp_dist := absf(to_player.dot(Vector2(-direction.y, direction.x)))
	if perp_dist > beam_width * 0.5:
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", beam_damage)


# ========== 技能 4：蓝色光柱阵 ==========

func _trigger_pillars() -> void:
	if _player == null:
		return
	for i in range(pillars_count):
		var angle := TAU * float(i) / float(pillars_count) + randf() * 0.3
		var dist := randf_range(pillars_spread_min, pillars_spread_max)
		var pos := _player.global_position + Vector2.RIGHT.rotated(angle) * dist
		var marker := _create_pillar_marker(pos)
		_pillar_markers.append({
			"node": marker,
			"timer": pillars_warning_time,
			"state": 0,
		})


func _create_pillar_marker(pos: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.name = "LiepingPillarMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.2, 0.5, 0.95, 0.5)
	warn.polygon = _make_circle_polygon(pillars_radius, 20)
	marker.add_child(warn)

	var explosion := Polygon2D.new()
	explosion.name = "Explosion"
	explosion.color = Color(0.4, 0.85, 1.0, 0.65)
	explosion.polygon = _make_circle_polygon(pillars_radius * 1.05, 20)
	explosion.visible = false
	marker.add_child(explosion)

	return marker


func _process_pillar_markers(delta: float) -> void:
	var i := _pillar_markers.size() - 1
	while i >= 0:
		var p := _pillar_markers[i]
		var node := p["node"] as Node2D
		if not is_instance_valid(node):
			_pillar_markers.remove_at(i)
			i -= 1
			continue
		p["timer"] = float(p["timer"]) - delta
		if int(p["state"]) == 0 and float(p["timer"]) <= 0.0:
			_detonate_pillar(node)
			p["state"] = 1
			p["timer"] = 0.15
		elif int(p["state"]) == 1 and float(p["timer"]) <= 0.0:
			node.queue_free()
			_pillar_markers.remove_at(i)
		i -= 1


func _detonate_pillar(marker: Node2D) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false
	var explosion := marker.get_node_or_null("Explosion") as Polygon2D
	if explosion != null:
		explosion.visible = true
	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= pillars_radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", pillars_damage)


# ========== 技能 6：镇压（全屏减速）==========

func _trigger_suppress() -> void:
	if _player == null:
		return
	if _player.has_method("apply_terrain_effect"):
		# SLOW = 0（与 TerrainEffect.Type.SLOW 对齐）
		_player.call("apply_terrain_effect", 0, suppress_duration)
	var timer := get_tree().create_timer(suppress_duration)
	timer.timeout.connect(_on_suppress_end)


func _on_suppress_end() -> void:
	if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", 0)


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
	# 将各计时器收紧到暴怒 CD 上限（避免刚触发就又等很久）
	_traps_timer = minf(_traps_timer, traps_cooldown * enrage_cd_multiplier * 0.5)
	_beam_timer = minf(_beam_timer, beam_cooldown * enrage_cd_multiplier * 0.5)
	_pillars_timer = minf(_pillars_timer, pillars_cooldown * enrage_cd_multiplier * 0.5)
	_suppress_timer = minf(_suppress_timer, suppress_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.4, 0.3, 0.85, 1.0)
	if _enraged_aura != null:
		_enraged_aura.visible = true


func _get_cd_multiplier() -> float:
	if _is_enraged:
		return enrage_cd_multiplier
	return 1.0


# ========== 死亡清场 ==========

func _die() -> void:
	for t in _trap_markers:
		var n = t["node"]
		if is_instance_valid(n):
			n.queue_free()
	_trap_markers.clear()
	for p in _pillar_markers:
		var n = p["node"]
		if is_instance_valid(n):
			n.queue_free()
	_pillar_markers.clear()
	if is_instance_valid(_beam_marker):
		_beam_marker.queue_free()
	_beam_marker = null
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
