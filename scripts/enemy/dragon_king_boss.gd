class_name DragonKingBoss
extends Enemy

## 东海蛟龙王 B301（L004 四·东海龙宫）
##
## 设计 §3 L004：4 技能套餐：
## - 技能 1 龙爪横扫（cd 4s）：扇形 110°/150px/18dmg
## - 技能 2 龙息水柱（cd 6.5s）：宽线 80×400 贯穿/22dmg
## - 技能 3 召唤水鬼（cd 8s）：4 只 E302 water_ghost
## - 技能 4 龙尾卷浪（cd 10s / 暴怒 6.5s）：外扩冲击环 300px/25dmg + apply_water_push
## 暴怒（35% HP）：cd×0.70 速×1.3 伤×1.25=30
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L004

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const WATER_GHOST_ARCHETYPE: Resource = preload("res://resources/enemies/water_ghost.tres")

# 技能 1 龙爪横扫
@export var claw_cooldown: float = 4.0
@export var claw_warning_time: float = 0.55
@export var claw_arc_degrees: float = 110.0
@export var claw_radius: float = 150.0
@export var claw_damage: float = 18.0

# 技能 2 龙息水柱
@export var breath_cooldown: float = 6.5
@export var breath_warning_time: float = 0.7
@export var breath_width: float = 80.0
@export var breath_length: float = 400.0
@export var breath_damage: float = 22.0

# 技能 3 召唤水鬼
@export var summon_cooldown: float = 8.0
@export var summon_count: int = 4

# 技能 4 龙尾卷浪
@export var wave_burst_cooldown: float = 10.0
@export var wave_burst_warning_time: float = 0.8
@export var wave_burst_radius: float = 300.0
@export var wave_burst_damage: float = 25.0
@export var wave_push_strength: float = 250.0

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.3
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.70

var _claw_timer: float = 0.0
var _breath_timer: float = 0.0
var _summon_timer: float = 0.0
var _wave_burst_timer: float = 0.0
var _is_enraged: bool = false
var _burst_markers: Array[Dictionary] = []

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	claw_cooldown = maxf(claw_cooldown, 0.1)
	claw_warning_time = maxf(claw_warning_time, 0.05)
	claw_radius = maxf(claw_radius, 8.0)
	claw_damage = maxf(claw_damage, 0.0)
	breath_cooldown = maxf(breath_cooldown, 0.1)
	breath_warning_time = maxf(breath_warning_time, 0.05)
	breath_width = maxf(breath_width, 8.0)
	breath_length = maxf(breath_length, 8.0)
	breath_damage = maxf(breath_damage, 0.0)
	summon_cooldown = maxf(summon_cooldown, 0.1)
	summon_count = maxi(summon_count, 0)
	wave_burst_cooldown = maxf(wave_burst_cooldown, 0.1)
	wave_burst_warning_time = maxf(wave_burst_warning_time, 0.05)
	wave_burst_radius = maxf(wave_burst_radius, 8.0)
	wave_burst_damage = maxf(wave_burst_damage, 0.0)
	wave_push_strength = maxf(wave_push_strength, 0.0)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_claw_timer = 2.5
	_breath_timer = 5.0
	_summon_timer = 7.0
	_wave_burst_timer = 9.5

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(70.0, 32)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_burst_markers(delta)

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
	_claw_timer -= delta
	_breath_timer -= delta
	_summon_timer -= delta
	_wave_burst_timer -= delta

	# 技能触发优先级：卷浪 > 召唤 > 龙息 > 龙爪
	if _wave_burst_timer <= 0.0:
		_trigger_wave_burst()
		_wave_burst_timer = wave_burst_cooldown * _get_cd_multiplier()
	elif _summon_timer <= 0.0:
		_trigger_summon()
		_summon_timer = summon_cooldown * _get_cd_multiplier()
	elif _breath_timer <= 0.0:
		_trigger_breath()
		_breath_timer = breath_cooldown * _get_cd_multiplier()
	elif _claw_timer <= 0.0:
		_trigger_claw()
		_claw_timer = claw_cooldown * _get_cd_multiplier()


# ========== 技能 1：龙爪横扫（扇形 AOE）==========

func _trigger_claw() -> void:
	if _player == null:
		return
	_spawn_claw_marker()


func _spawn_claw_marker() -> void:
	var marker := Node2D.new()
	marker.name = "ClawMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var direction := global_position.direction_to(_player.global_position)
	var base_angle := direction.angle()

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.3, 0.7, 1.0, 0.35)
	warn.polygon = _make_arc_polygon(claw_radius, claw_arc_degrees, base_angle, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": claw_warning_time,
		"state": 0,
		"type": "claw",
		"base_angle": base_angle,
	})


func _detonate_claw(marker: Node2D, base_angle: float) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.5, 0.9, 1.0, 0.65)
	flash.polygon = _make_arc_polygon(claw_radius * 1.05, claw_arc_degrees, base_angle, 20)
	marker.add_child(flash)

	if is_instance_valid(_player):
		var diff := _player.global_position - marker.global_position
		var dist := diff.length()
		if dist <= claw_radius:
			var player_angle := diff.angle()
			var half_arc := deg_to_rad(claw_arc_degrees * 0.5)
			var angle_diff := absf(wrapf(player_angle - base_angle, -PI, PI))
			if angle_diff <= half_arc:
				if _player.has_method("take_damage"):
					_player.call("take_damage", claw_damage)


# ========== 技能 2：龙息水柱（宽矩形贯穿）==========

func _trigger_breath() -> void:
	if _player == null:
		return
	_spawn_breath_marker()


func _spawn_breath_marker() -> void:
	var marker := Node2D.new()
	marker.name = "BreathMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var direction := global_position.direction_to(_player.global_position)
	var angle := direction.angle()

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.2, 0.6, 0.9, 0.4)
	warn.polygon = _make_rect_polygon(breath_width, breath_length, angle)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": breath_warning_time,
		"state": 0,
		"type": "breath",
		"angle": angle,
	})


func _detonate_breath(marker: Node2D, angle: float) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.35, 0.75, 1.0, 0.7)
	flash.polygon = _make_rect_polygon(breath_width * 1.05, breath_length, angle)
	marker.add_child(flash)

	if is_instance_valid(_player):
		# 转换玩家坐标到矩形本地空间检测
		var local_pos := (_player.global_position - marker.global_position).rotated(-angle)
		if absf(local_pos.x) <= breath_width * 0.5 and local_pos.y >= 0.0 and local_pos.y <= breath_length:
			if _player.has_method("take_damage"):
				_player.call("take_damage", breath_damage)


# ========== 技能 3：召唤水鬼 ==========

func _trigger_summon() -> void:
	if WATER_GHOST_ARCHETYPE == null or ENEMY_SCENE == null:
		return
	for i in range(summon_count):
		var enemy_node := ENEMY_SCENE.instantiate()
		if enemy_node == null:
			continue
		var parent := _get_effect_parent()
		parent.add_child(enemy_node)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 180.0)
		enemy_node.global_position = global_position + offset
		if "max_hp" in enemy_node:
			enemy_node.max_hp = WATER_GHOST_ARCHETYPE.max_hp
		if "current_hp" in enemy_node:
			enemy_node.current_hp = WATER_GHOST_ARCHETYPE.max_hp
		if "move_speed" in enemy_node:
			enemy_node.move_speed = WATER_GHOST_ARCHETYPE.move_speed
		if "damage" in enemy_node:
			enemy_node.damage = WATER_GHOST_ARCHETYPE.damage
		if "xp_drop_value" in enemy_node:
			enemy_node.xp_drop_value = WATER_GHOST_ARCHETYPE.xp_drop_value
		if "_body" in enemy_node and is_instance_valid(enemy_node._body):
			enemy_node._body.color = WATER_GHOST_ARCHETYPE.body_color


# ========== 技能 4：龙尾卷浪（冲击环 + 水流推送）==========

func _trigger_wave_burst() -> void:
	if _player == null:
		return
	_spawn_wave_ring_marker()


func _spawn_wave_ring_marker() -> void:
	var marker := Node2D.new()
	marker.name = "WaveRingMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.2, 0.55, 0.9, 0.38)
	warn.polygon = _make_ring_polygon(wave_burst_radius - 30.0, wave_burst_radius, 32)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": wave_burst_warning_time,
		"state": 0,
		"type": "wave_burst",
	})


func _detonate_wave_burst(marker: Node2D) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.3, 0.7, 1.0, 0.65)
	flash.polygon = _make_ring_polygon(wave_burst_radius - 28.0, wave_burst_radius * 1.05, 32)
	marker.add_child(flash)

	if is_instance_valid(_player):
		var dist := _player.global_position.distance_to(marker.global_position)
		if dist <= wave_burst_radius:
			# 造成伤害
			if _player.has_method("take_damage"):
				_player.call("take_damage", wave_burst_damage)
			# 水流推力：将玩家从 Boss 处推离（体现水机制）
			if _player.has_method("apply_water_push"):
				var push_dir := Vector2.RIGHT
				if dist > 0.1:
					push_dir = (_player.global_position - marker.global_position).normalized()
				_player.call("apply_water_push", push_dir * wave_push_strength)


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
			if type == "claw":
				_detonate_claw(node, float(t["base_angle"]))
			elif type == "breath":
				_detonate_breath(node, float(t["angle"]))
			elif type == "wave_burst":
				_detonate_wave_burst(node)
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
	claw_damage *= enrage_damage_multiplier
	breath_damage *= enrage_damage_multiplier
	wave_burst_damage *= enrage_damage_multiplier
	# 收紧各计时器到暴怒 CD 上限
	_claw_timer = minf(_claw_timer, claw_cooldown * enrage_cd_multiplier * 0.5)
	_breath_timer = minf(_breath_timer, breath_cooldown * enrage_cd_multiplier * 0.5)
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_cd_multiplier * 0.5)
	_wave_burst_timer = minf(_wave_burst_timer, wave_burst_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.5, 0.85, 1.0, 1.0)
	if _enraged_aura != null:
		_enraged_aura.visible = true


func _get_cd_multiplier() -> float:
	if _is_enraged:
		return enrage_cd_multiplier
	return 1.0


# ========== 死亡清场 ==========

func _die() -> void:
	for t in _burst_markers:
		var n = t["node"]
		if is_instance_valid(n):
			n.queue_free()
	_burst_markers.clear()
	super._die()


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


func _make_ring_polygon(inner_r: float, outer_r: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n := maxi(point_count, 6)
	for i in range(n):
		var angle := TAU * float(i) / float(n)
		points.append(Vector2.RIGHT.rotated(angle) * outer_r)
	for i in range(n):
		var angle := TAU * float(n - 1 - i) / float(n)
		points.append(Vector2.RIGHT.rotated(angle) * inner_r)
	return points


func _make_rect_polygon(width: float, length: float, angle: float) -> PackedVector2Array:
	var half_w := width * 0.5
	var corners := PackedVector2Array([
		Vector2(-half_w, 0.0),
		Vector2(half_w, 0.0),
		Vector2(half_w, length),
		Vector2(-half_w, length),
	])
	var rotated_corners := PackedVector2Array()
	for c in corners:
		rotated_corners.append(c.rotated(angle))
	return rotated_corners


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
