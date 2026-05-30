class_name ShiDianYanJunBoss
extends Enemy

## 十殿阎君 B701（L008 八·酆都地府）
##
## 4 技能套餐：
## - 技能 1 六道判决（cd 5s）：玩家周围 6 点阴火 + CURSE 区 5s
## - 技能 2 黑无常锁链（cd 7s）：宽线命中 SNARE 2s / 25dmg
## - 技能 3 十殿召兵（cd 9s）：3 冥卒 + 2 阴差骑
## - 技能 4 轮回审判（cd 14s / 暴怒 9s）：全屏 CURSE 8s + 8 点阴火
## 暴怒（35% HP）：cd×0.65 速×1.35 伤×1.25=40
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L008

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const HELL_SOLDIER_ARCHETYPE: Resource = preload("res://resources/enemies/hell_soldier.tres")
const YIN_CAVALRY_ARCHETYPE: Resource = preload("res://resources/enemies/yin_cavalry.tres")
const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

# 技能 1 六道判决
@export var liudao_cooldown: float = 5.0
@export var liudao_count: int = 6
@export var liudao_spread: float = 200.0
@export var liudao_warning_time: float = 0.7
@export var liudao_curse_radius: float = 45.0
@export var liudao_curse_duration: float = 5.0
@export var liudao_fire_damage: float = 20.0
@export var liudao_fire_radius: float = 55.0

# 技能 2 黑无常锁链
@export var chain_cooldown: float = 7.0
@export var chain_warning_time: float = 0.8
@export var chain_damage: float = 25.0
@export var chain_width: float = 60.0
@export var chain_length: float = 300.0
@export var chain_snare_duration: float = 2.0

# 技能 3 十殿召兵
@export var summon_cooldown: float = 9.0
@export var summon_soldier_count: int = 3
@export var summon_cavalry_count: int = 2

# 技能 4 轮回审判
@export var judgment_cooldown: float = 14.0
@export var judgment_enraged_cooldown: float = 9.0
@export var judgment_curse_duration: float = 8.0
@export var judgment_fire_count: int = 8
@export var judgment_fire_radius: float = 55.0
@export var judgment_fire_damage: float = 20.0
@export var judgment_fire_spread: float = 260.0
@export var judgment_warning_time: float = 1.0

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.35
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.65

var _liudao_timer: float = 3.0
var _chain_timer: float = 5.5
var _summon_timer: float = 7.5
var _judgment_timer: float = 11.0
var _is_enraged: bool = false
var _burst_markers: Array[Dictionary] = []

# SNARE/CURSE 移除计时
var _snare_remove_timer: float = 0.0
var _snare_active: bool = false
var _curse_remove_timers: Array[float] = []

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	liudao_cooldown = maxf(liudao_cooldown, 0.1)
	chain_cooldown = maxf(chain_cooldown, 0.1)
	summon_cooldown = maxf(summon_cooldown, 0.1)
	judgment_cooldown = maxf(judgment_cooldown, 0.1)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(65.0, 32)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_cleanup_effects()
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_burst_markers(delta)
	_process_snare_timer(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_liudao_timer -= delta
	_chain_timer -= delta
	_summon_timer -= delta
	_judgment_timer -= delta

	# 技能触发优先级：轮回审判 > 六道判决 > 黑无常锁链 > 十殿召兵
	if _judgment_timer <= 0.0:
		_trigger_judgment()
		var jcd: float = judgment_enraged_cooldown if _is_enraged else judgment_cooldown
		_judgment_timer = jcd * _get_cd_multiplier()
	elif _liudao_timer <= 0.0:
		_trigger_liudao()
		_liudao_timer = liudao_cooldown * _get_cd_multiplier()
	elif _chain_timer <= 0.0:
		_trigger_chain()
		_chain_timer = chain_cooldown * _get_cd_multiplier()
	elif _summon_timer <= 0.0:
		_trigger_summon()
		_summon_timer = summon_cooldown * _get_cd_multiplier()

	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


# ========== 技能 1：六道判决（6 点阴火 + CURSE 区）==========

func _trigger_liudao() -> void:
	if _player == null:
		return
	for i in range(liudao_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, liudao_spread)
		var pos := _player.global_position + offset
		_spawn_fire_marker(pos, liudao_fire_radius, liudao_fire_damage, liudao_warning_time, true)


func _spawn_fire_marker(pos: Vector2, radius: float, dmg: float, warn_time: float, spawn_curse: bool) -> void:
	var marker := Node2D.new()
	marker.name = "FireMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.2, 0.55, 0.3, 0.40)
	warn.polygon = _make_circle_polygon(radius, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": warn_time,
		"state": 0,
		"radius": radius,
		"damage": dmg,
		"spawn_curse": spawn_curse,
	})


# ========== 技能 2：黑无常锁链（线形 SNARE）==========

func _trigger_chain() -> void:
	if _player == null:
		return
	var marker := Node2D.new()
	marker.name = "ChainMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var dir := global_position.direction_to(_player.global_position)
	var angle := dir.angle()

	# 宽线预警
	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.15, 0.5, 0.35, 0.45)
	var half_w: float = chain_width * 0.5
	var pts := PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(half_w, 0),
		Vector2(half_w, chain_length),
		Vector2(-half_w, chain_length),
	])
	warn.polygon = pts
	warn.rotation = angle - PI * 0.5
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": chain_warning_time,
		"state": 0,
		"radius": 0.0,
		"damage": chain_damage,
		"spawn_curse": false,
		"is_chain": true,
		"chain_dir": dir,
	})


func _detonate_chain(marker: Node2D, dmg: float, dir: Vector2) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.25, 0.65, 0.45, 0.6)
	var half_w: float = chain_width * 0.5
	flash.polygon = PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(half_w, 0),
		Vector2(half_w, chain_length),
		Vector2(-half_w, chain_length),
	])
	flash.rotation = dir.angle() - PI * 0.5
	marker.add_child(flash)

	if not is_instance_valid(_player):
		return
	# 检测玩家是否在线形区域内
	var to_player: Vector2 = _player.global_position - marker.global_position
	var forward: float = to_player.dot(dir)
	var lateral: float = absf(to_player.dot(dir.orthogonal()))
	if forward >= 0.0 and forward <= chain_length and lateral <= chain_width * 0.5:
		if _player.has_method("take_damage"):
			_player.call("take_damage", dmg)
		_apply_snare_to_player()


func _apply_snare_to_player() -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("apply_terrain_effect"):
		_player.call("apply_terrain_effect", TerrainEffect.Type.SNARE, chain_snare_duration)
	_snare_active = true
	_snare_remove_timer = chain_snare_duration


func _process_snare_timer(delta: float) -> void:
	if not _snare_active:
		return
	_snare_remove_timer -= delta
	if _snare_remove_timer <= 0.0:
		_snare_active = false
		if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
			_player.call("remove_terrain_effect", TerrainEffect.Type.SNARE)


# ========== 技能 3：十殿召兵 ==========

func _trigger_summon() -> void:
	_spawn_enemies(HELL_SOLDIER_ARCHETYPE, summon_soldier_count)
	_spawn_enemies(YIN_CAVALRY_ARCHETYPE, summon_cavalry_count)


func _spawn_enemies(archetype: Resource, count: int) -> void:
	if archetype == null or ENEMY_SCENE == null:
		return
	for i in range(count):
		var enemy_node := ENEMY_SCENE.instantiate()
		if enemy_node == null:
			continue
		var parent := _get_effect_parent()
		parent.add_child(enemy_node)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(90.0, 200.0)
		enemy_node.global_position = global_position + offset
		if "max_hp" in enemy_node:
			enemy_node.max_hp = archetype.max_hp
		if "current_hp" in enemy_node:
			enemy_node.current_hp = archetype.max_hp
		if "move_speed" in enemy_node:
			enemy_node.move_speed = archetype.move_speed
		if "damage" in enemy_node:
			enemy_node.damage = archetype.damage
		if "xp_drop_value" in enemy_node:
			enemy_node.xp_drop_value = archetype.xp_drop_value
		if "_body" in enemy_node and is_instance_valid(enemy_node._body):
			enemy_node._body.color = archetype.body_color


# ========== 技能 4：轮回审判（全屏 CURSE + 8 点阴火）==========

func _trigger_judgment() -> void:
	if _player == null:
		return
	# 全屏 CURSE
	_apply_judgment_curse()
	# 8 点阴火
	for i in range(judgment_fire_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, judgment_fire_spread)
		var pos := _player.global_position + offset
		_spawn_fire_marker(pos, judgment_fire_radius, judgment_fire_damage, judgment_warning_time, false)


func _apply_judgment_curse() -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("apply_terrain_effect"):
		_player.call("apply_terrain_effect", TerrainEffect.Type.CURSE, judgment_curse_duration)
	# Timer 到期后自动移除 CURSE
	var timer := get_tree().create_timer(judgment_curse_duration)
	timer.timeout.connect(_remove_judgment_curse)


func _remove_judgment_curse() -> void:
	if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.CURSE)


# ========== 通用落点处理 ==========

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
			if t.get("is_chain", false):
				_detonate_chain(node, float(t["damage"]), t["chain_dir"] as Vector2)
			else:
				_detonate_fire(node, float(t["radius"]), float(t["damage"]), bool(t["spawn_curse"]))
			t["state"] = 1
			t["timer"] = 0.18
		elif int(t["state"]) == 1 and float(t["timer"]) <= 0.0:
			node.queue_free()
			_burst_markers.remove_at(i)
		i -= 1


func _detonate_fire(marker: Node2D, radius: float, dmg: float, spawn_curse: bool) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.2, 0.7, 0.4, 0.65)
	flash.polygon = _make_circle_polygon(radius * 1.05, 20)
	marker.add_child(flash)

	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", dmg)

	if spawn_curse:
		_spawn_curse_at(marker.global_position, liudao_curse_radius, liudao_curse_duration)


func _spawn_curse_at(pos: Vector2, radius: float, duration: float) -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.CURSE
	te.effect_radius = radius
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = pos
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(te.queue_free)


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
	liudao_fire_damage *= enrage_damage_multiplier
	chain_damage *= enrage_damage_multiplier
	judgment_fire_damage *= enrage_damage_multiplier
	_liudao_timer = minf(_liudao_timer, liudao_cooldown * enrage_cd_multiplier * 0.5)
	_chain_timer = minf(_chain_timer, chain_cooldown * enrage_cd_multiplier * 0.5)
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_cd_multiplier * 0.5)
	_judgment_timer = minf(_judgment_timer, judgment_enraged_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.15, 0.7, 0.45, 1.0)
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
	# 移除残留 SNARE/CURSE
	if _snare_active and is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.SNARE)
	_snare_active = false
	if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.CURSE)


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
	var par := get_parent()
	if par != null:
		return par
	return self
