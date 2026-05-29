class_name YellowWindBoss
extends Enemy

## 黄风大圣 B601（L007 七·黄风岭，v0.7）
##
## 设计 §3 L007：4 技能套餐：
## - 技能 1 三昧神风（cd 4s）：扇形 90°/200px/22dmg + 对玩家 apply_water_push 推力
## - 技能 2 沙尘落石（cd 5s）：5 点落石 55px/18dmg
## - 技能 3 召唤沙煞（cd 8s）：6 只 E601 沙尘煞（Enemy.tscn + sand_demon.tres）
## - 技能 4 黄风漩涡（cd 13s / 暴怒 8.5s）：外扩旋风 PUSH 1.5s + 4 点落石
## 暴怒（35% HP）：cd×0.65 速×1.33 伤×1.25=37

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const SAND_DEMON_ARCHETYPE: Resource = preload("res://resources/enemies/sand_demon.tres")

# 技能 1 三昧神风
@export var wind_slash_cooldown: float = 4.0
@export var wind_slash_warning_time: float = 0.7
@export var wind_slash_angle_deg: float = 90.0
@export var wind_slash_range: float = 200.0
@export var wind_slash_damage: float = 22.0
@export var wind_slash_push_strength: float = 200.0

# 技能 2 沙尘落石
@export var rockfall_cooldown: float = 5.0
@export var rockfall_warning_time: float = 0.85
@export var rockfall_count: int = 5
@export var rockfall_radius: float = 55.0
@export var rockfall_damage: float = 18.0
@export var rockfall_spread: float = 200.0

# 技能 3 召唤沙煞
@export var summon_cooldown: float = 8.0
@export var summon_count: int = 6

# 技能 4 黄风漩涡
@export var vortex_cooldown: float = 13.0
@export var vortex_push_duration: float = 1.5
@export var vortex_push_strength: float = 180.0
@export var vortex_rock_count: int = 4
@export var vortex_rock_radius: float = 55.0
@export var vortex_rock_damage: float = 18.0
@export var vortex_rock_spread: float = 160.0
@export var vortex_warning_time: float = 0.85

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.33
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.65

var _wind_slash_timer: float = 0.0
var _rockfall_timer: float = 0.0
var _summon_timer: float = 0.0
var _vortex_timer: float = 0.0
var _is_enraged: bool = false

# 黄风漩涡 PUSH 持续计时
var _vortex_push_active: bool = false
var _vortex_push_remaining: float = 0.0

var _burst_markers: Array[Dictionary] = []
var _wind_slash_marker: Dictionary = {}

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	wind_slash_cooldown = maxf(wind_slash_cooldown, 0.1)
	wind_slash_warning_time = maxf(wind_slash_warning_time, 0.05)
	wind_slash_angle_deg = clampf(wind_slash_angle_deg, 10.0, 360.0)
	wind_slash_range = maxf(wind_slash_range, 4.0)
	wind_slash_damage = maxf(wind_slash_damage, 0.0)
	wind_slash_push_strength = maxf(wind_slash_push_strength, 0.0)
	rockfall_cooldown = maxf(rockfall_cooldown, 0.1)
	rockfall_warning_time = maxf(rockfall_warning_time, 0.05)
	rockfall_count = maxi(rockfall_count, 1)
	rockfall_radius = maxf(rockfall_radius, 4.0)
	rockfall_damage = maxf(rockfall_damage, 0.0)
	rockfall_spread = maxf(rockfall_spread, 8.0)
	summon_cooldown = maxf(summon_cooldown, 0.1)
	summon_count = maxi(summon_count, 0)
	vortex_cooldown = maxf(vortex_cooldown, 0.1)
	vortex_push_duration = maxf(vortex_push_duration, 0.1)
	vortex_push_strength = maxf(vortex_push_strength, 0.0)
	vortex_rock_count = maxi(vortex_rock_count, 0)
	vortex_rock_radius = maxf(vortex_rock_radius, 4.0)
	vortex_rock_damage = maxf(vortex_rock_damage, 0.0)
	vortex_rock_spread = maxf(vortex_rock_spread, 8.0)
	vortex_warning_time = maxf(vortex_warning_time, 0.05)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_wind_slash_timer = 2.5
	_rockfall_timer = 4.0
	_summon_timer = 6.5
	_vortex_timer = 10.0

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(50.0, 32)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_burst_markers(delta)
	_process_wind_slash_marker(delta)
	_process_vortex_push(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_wind_slash_timer -= delta
	_rockfall_timer -= delta
	_summon_timer -= delta
	_vortex_timer -= delta

	# 技能触发（优先级：漩涡 > 召唤 > 落石 > 神风）
	if _vortex_timer <= 0.0:
		_trigger_vortex()
		_vortex_timer = vortex_cooldown * _get_cd_multiplier()
	elif _summon_timer <= 0.0:
		_trigger_summon()
		_summon_timer = summon_cooldown * _get_cd_multiplier()
	elif _rockfall_timer <= 0.0:
		_trigger_rockfall()
		_rockfall_timer = rockfall_cooldown * _get_cd_multiplier()
	elif _wind_slash_timer <= 0.0:
		_trigger_wind_slash()
		_wind_slash_timer = wind_slash_cooldown * _get_cd_multiplier()

	# 慢速追击
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


# ========== 技能 1：三昧神风（扇形 AOE + PUSH）==========

func _trigger_wind_slash() -> void:
	if _player == null:
		return
	var slash_dir := global_position.direction_to(_player.global_position)
	var marker := Node2D.new()
	marker.name = "WindSlashMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var half_angle := deg_to_rad(wind_slash_angle_deg * 0.5)
	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.9, 0.75, 0.25, 0.38)
	var fan_points := PackedVector2Array()
	fan_points.append(Vector2.ZERO)
	var segments: int = 18
	for j in range(segments + 1):
		var a := slash_dir.angle() - half_angle + (float(j) / float(segments)) * (half_angle * 2.0)
		fan_points.append(Vector2.RIGHT.rotated(a) * wind_slash_range)
	warn.polygon = fan_points
	marker.add_child(warn)

	_wind_slash_marker = {
		"node": marker,
		"timer": wind_slash_warning_time,
		"state": 0,
		"dir": slash_dir,
	}


func _process_wind_slash_marker(delta: float) -> void:
	if _wind_slash_marker.is_empty():
		return
	var node := _wind_slash_marker.get("node") as Node2D
	if not is_instance_valid(node):
		_wind_slash_marker = {}
		return
	_wind_slash_marker["timer"] = float(_wind_slash_marker["timer"]) - delta
	if int(_wind_slash_marker["state"]) == 0 and float(_wind_slash_marker["timer"]) <= 0.0:
		_detonate_wind_slash(node)
		_wind_slash_marker["state"] = 1
		_wind_slash_marker["timer"] = 0.2
	elif int(_wind_slash_marker["state"]) == 1 and float(_wind_slash_marker["timer"]) <= 0.0:
		node.queue_free()
		_wind_slash_marker = {}


func _detonate_wind_slash(marker: Node2D) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.color = Color(1.0, 0.88, 0.45, 0.7)
	if not is_instance_valid(_player):
		return
	var slash_dir: Vector2 = _wind_slash_marker.get("dir", Vector2.RIGHT)
	var half_angle := deg_to_rad(wind_slash_angle_deg * 0.5)
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > wind_slash_range:
		return
	if dist < 0.01:
		return
	var angle_to_player := to_player.angle()
	var angle_diff := absf(wrapf(angle_to_player - slash_dir.angle(), -PI, PI))
	if angle_diff > half_angle:
		return
	# 造成伤害
	if _player.has_method("take_damage"):
		_player.call("take_damage", wind_slash_damage)
	# 施加风力推力：沿玩家远离 Boss 方向推
	if _player.has_method("apply_water_push"):
		var push_dir := to_player.normalized()
		_player.call("apply_water_push", push_dir * wind_slash_push_strength)


# ========== 技能 2：沙尘落石（多点落石 AOE）==========

func _trigger_rockfall() -> void:
	if _player == null:
		return
	for i in range(rockfall_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, rockfall_spread)
		var pos := _player.global_position + offset
		_spawn_burst_marker(pos, rockfall_warning_time, rockfall_radius, rockfall_damage)


func _spawn_burst_marker(pos: Vector2, warn_time: float, radius: float, dmg: float) -> void:
	var marker := Node2D.new()
	marker.name = "BurstMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.85, 0.65, 0.2, 0.4)
	warn.polygon = _make_circle_polygon(radius, 20)
	marker.add_child(warn)

	var explosion := Polygon2D.new()
	explosion.name = "Explosion"
	explosion.color = Color(0.95, 0.8, 0.35, 0.75)
	explosion.polygon = _make_circle_polygon(radius * 1.05, 20)
	explosion.visible = false
	marker.add_child(explosion)

	_burst_markers.append({
		"node": marker,
		"timer": warn_time,
		"state": 0,
		"radius": radius,
		"damage": dmg,
	})


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
			_detonate_burst(node, float(t["radius"]), float(t["damage"]))
			t["state"] = 1
			t["timer"] = 0.18
		elif int(t["state"]) == 1 and float(t["timer"]) <= 0.0:
			node.queue_free()
			_burst_markers.remove_at(i)
		i -= 1


func _detonate_burst(marker: Node2D, radius: float, dmg: float) -> void:
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


# ========== 技能 3：召唤沙煞（批量生成 E601）==========

func _trigger_summon() -> void:
	for i in range(summon_count):
		_summon_sand_demon()


func _summon_sand_demon() -> void:
	if SAND_DEMON_ARCHETYPE == null or ENEMY_SCENE == null:
		return
	var enemy_node := ENEMY_SCENE.instantiate()
	if enemy_node == null:
		return
	var parent := _get_effect_parent()
	parent.add_child(enemy_node)
	# 随机偏移生成位置，避免堆叠
	var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 190.0)
	enemy_node.global_position = global_position + offset
	# 应用沙尘煞 archetype 数值（duck typing）
	if "max_hp" in enemy_node:
		enemy_node.max_hp = SAND_DEMON_ARCHETYPE.max_hp
	if "current_hp" in enemy_node:
		enemy_node.current_hp = SAND_DEMON_ARCHETYPE.max_hp
	if "move_speed" in enemy_node:
		enemy_node.move_speed = SAND_DEMON_ARCHETYPE.move_speed
	if "damage" in enemy_node:
		enemy_node.damage = SAND_DEMON_ARCHETYPE.damage
	if "xp_drop_value" in enemy_node:
		enemy_node.xp_drop_value = SAND_DEMON_ARCHETYPE.xp_drop_value
	if "_body" in enemy_node and is_instance_valid(enemy_node._body):
		enemy_node._body.color = SAND_DEMON_ARCHETYPE.body_color


# ========== 技能 4：黄风漩涡（全场 PUSH + 落石）==========

func _trigger_vortex() -> void:
	if _player == null:
		return
	# 启动持续 PUSH
	_vortex_push_active = true
	_vortex_push_remaining = vortex_push_duration
	# 生成 4 点落石
	for i in range(vortex_rock_count):
		var angle := TAU * float(i) / float(vortex_rock_count)
		var offset := Vector2.RIGHT.rotated(angle) * randf_range(60.0, vortex_rock_spread)
		var pos := _player.global_position + offset
		_spawn_burst_marker(pos, vortex_warning_time, vortex_rock_radius, vortex_rock_damage)


func _process_vortex_push(delta: float) -> void:
	if not _vortex_push_active:
		return
	_vortex_push_remaining -= delta
	if _vortex_push_remaining <= 0.0:
		_vortex_push_active = false
		return
	# 每帧对玩家施加向外推力（远离 Boss）
	if is_instance_valid(_player) and _player.has_method("apply_water_push"):
		var to_player := _player.global_position - global_position
		if to_player.length() > 0.01:
			var push_dir := to_player.normalized()
			_player.call("apply_water_push", push_dir * vortex_push_strength * delta)


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
	_wind_slash_timer = minf(_wind_slash_timer, wind_slash_cooldown * enrage_cd_multiplier * 0.5)
	_rockfall_timer = minf(_rockfall_timer, rockfall_cooldown * enrage_cd_multiplier * 0.5)
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_cd_multiplier * 0.5)
	_vortex_timer = minf(_vortex_timer, vortex_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.92, 0.78, 0.18, 1.0)
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
	if not _wind_slash_marker.is_empty():
		var n = _wind_slash_marker.get("node")
		if is_instance_valid(n):
			n.queue_free()
	_wind_slash_marker = {}
	_vortex_push_active = false
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
