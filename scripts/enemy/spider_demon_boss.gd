class_name SpiderDemonBoss
extends Enemy

## 蜘蛛精 B501（L006 六·盘丝岭）
##
## 4 技能套餐：
## - 技能 1 毒丝缠绕（cd 5s）：8 向毒丝，触碰玩家 SNARE 2.5s + 15dmg
## - 技能 2 毒液喷洒（cd 6s）：玩家周围 6 点 BURN 区 5s/3dps（绿色）
## - 技能 3 召网（cd 9s）：3 网妖 + 2 跳蛛
## - 技能 4 蛛后束缚（cd 14s / 暴怒 9s）：全场 SNARE 3s + SLOW 2s
## 暴怒（35% HP）：cd×0.65 速×1.30 伤×1.25=32
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L006

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const WEB_DEMON_SCENE: PackedScene = preload("res://scenes/enemy/WebDemon.tscn")
const JUMPING_SPIDER_SCENE: PackedScene = preload("res://scenes/enemy/JumpingSpider.tscn")
const WEB_DEMON_ARCHETYPE: Resource = preload("res://resources/enemies/web_demon.tres")
const JUMPING_SPIDER_ARCHETYPE: Resource = preload("res://resources/enemies/jumping_spider.tres")
const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

# 技能 1 毒丝缠绕
@export var silk_cooldown: float = 5.0
@export var silk_count: int = 8
@export var silk_length: float = 220.0
@export var silk_width: float = 22.0
@export var silk_damage: float = 15.0
@export var silk_snare_duration: float = 2.5
@export var silk_warning_time: float = 0.7

# 技能 2 毒液喷洒
@export var poison_cooldown: float = 6.0
@export var poison_count: int = 6
@export var poison_spread: float = 180.0
@export var poison_radius: float = 50.0
@export var poison_duration: float = 5.0
@export var poison_dps: float = 3.0
@export var poison_warning_time: float = 0.8

# 技能 3 召网
@export var summon_cooldown: float = 9.0
@export var summon_web_count: int = 3
@export var summon_jump_count: int = 2

# 技能 4 蛛后束缚
@export var bind_cooldown: float = 14.0
@export var bind_enraged_cooldown: float = 9.0
@export var bind_snare_duration: float = 3.0
@export var bind_slow_duration: float = 2.0
@export var bind_damage: float = 18.0
@export var bind_warning_time: float = 1.0

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.30
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.65

var _silk_timer: float = 3.0
var _poison_timer: float = 5.0
var _summon_timer: float = 7.0
var _bind_timer: float = 11.0
var _is_enraged: bool = false
var _burst_markers: Array[Dictionary] = []

# SNARE/SLOW 移除计时
var _snare_active: bool = false
var _snare_remove_timer: float = 0.0
var _slow_active: bool = false
var _slow_remove_timer: float = 0.0

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	silk_cooldown = maxf(silk_cooldown, 0.1)
	poison_cooldown = maxf(poison_cooldown, 0.1)
	summon_cooldown = maxf(summon_cooldown, 0.1)
	bind_cooldown = maxf(bind_cooldown, 0.1)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(70.0, 32)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_cleanup_effects()
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_burst_markers(delta)
	_process_snare_timer(delta)
	_process_slow_timer(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_silk_timer -= delta
	_poison_timer -= delta
	_summon_timer -= delta
	_bind_timer -= delta

	# 技能触发优先级：蛛后束缚 > 毒丝缠绕 > 毒液喷洒 > 召网
	if _bind_timer <= 0.0:
		_trigger_bind()
		var bcd: float = bind_enraged_cooldown if _is_enraged else bind_cooldown
		_bind_timer = bcd * _get_cd_multiplier()
	elif _silk_timer <= 0.0:
		_trigger_silk()
		_silk_timer = silk_cooldown * _get_cd_multiplier()
	elif _poison_timer <= 0.0:
		_trigger_poison()
		_poison_timer = poison_cooldown * _get_cd_multiplier()
	elif _summon_timer <= 0.0:
		_trigger_summon()
		_summon_timer = summon_cooldown * _get_cd_multiplier()

	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


# ========== 技能 1：毒丝缠绕（8 向线形 SNARE）==========

func _trigger_silk() -> void:
	if _player == null:
		return
	for i in range(silk_count):
		var angle := TAU * float(i) / float(silk_count)
		var dir := Vector2.RIGHT.rotated(angle)
		_spawn_silk_marker(dir)


func _spawn_silk_marker(dir: Vector2) -> void:
	var marker := Node2D.new()
	marker.name = "SilkMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.55, 0.2, 0.6, 0.40)
	var half_w: float = silk_width * 0.5
	var pts := PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(half_w, 0),
		Vector2(half_w, silk_length),
		Vector2(-half_w, silk_length),
	])
	warn.polygon = pts
	warn.rotation = dir.angle() - PI * 0.5
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": silk_warning_time,
		"state": 0,
		"type": "silk",
		"dir": dir,
	})


func _detonate_silk(marker: Node2D, dir: Vector2) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.65, 0.25, 0.7, 0.6)
	var half_w: float = silk_width * 0.5
	flash.polygon = PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(half_w, 0),
		Vector2(half_w, silk_length),
		Vector2(-half_w, silk_length),
	])
	flash.rotation = dir.angle() - PI * 0.5
	marker.add_child(flash)

	if not is_instance_valid(_player):
		return
	var to_player: Vector2 = _player.global_position - marker.global_position
	var forward: float = to_player.dot(dir)
	var lateral: float = absf(to_player.dot(dir.orthogonal()))
	if forward >= 0.0 and forward <= silk_length and lateral <= silk_width * 0.5:
		if _player.has_method("take_damage"):
			_player.call("take_damage", silk_damage)
		_apply_snare_to_player(silk_snare_duration)


func _apply_snare_to_player(duration: float) -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("apply_terrain_effect"):
		_player.call("apply_terrain_effect", TerrainEffect.Type.SNARE, duration)
	_snare_active = true
	_snare_remove_timer = duration


func _process_snare_timer(delta: float) -> void:
	if not _snare_active:
		return
	_snare_remove_timer -= delta
	if _snare_remove_timer <= 0.0:
		_snare_active = false
		if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
			_player.call("remove_terrain_effect", TerrainEffect.Type.SNARE)


# ========== 技能 2：毒液喷洒（BURN 区）==========

func _trigger_poison() -> void:
	if _player == null:
		return
	for i in range(poison_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, poison_spread)
		var pos := _player.global_position + offset
		_spawn_poison_marker(pos)


func _spawn_poison_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.name = "PoisonMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.2, 0.6, 0.15, 0.38)
	warn.polygon = _make_circle_polygon(poison_radius, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": poison_warning_time,
		"state": 0,
		"type": "poison",
	})


func _detonate_poison(marker: Node2D) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false

	var flash := Polygon2D.new()
	flash.color = Color(0.25, 0.7, 0.2, 0.55)
	flash.polygon = _make_circle_polygon(poison_radius * 1.05, 20)
	marker.add_child(flash)

	# 直接伤害
	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= poison_radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", poison_dps)

	# 生成持续 BURN 地形
	_spawn_burn_terrain(marker.global_position, poison_radius, poison_duration)


func _spawn_burn_terrain(pos: Vector2, radius: float, duration: float) -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.BURN
	te.effect_radius = radius
	te.burn_dps = poison_dps
	te.duration = 0.0
	var parent := _get_effect_parent()
	parent.add_child(te)
	te.global_position = pos
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(te.queue_free)


# ========== 技能 3：召网 ==========

func _trigger_summon() -> void:
	_spawn_custom_enemies(WEB_DEMON_SCENE, WEB_DEMON_ARCHETYPE, summon_web_count)
	_spawn_custom_enemies(JUMPING_SPIDER_SCENE, JUMPING_SPIDER_ARCHETYPE, summon_jump_count)


func _spawn_custom_enemies(scene: PackedScene, archetype: Resource, count: int) -> void:
	if scene == null or count <= 0:
		return
	var parent := _get_effect_parent()
	for i in range(count):
		var enemy_node := scene.instantiate()
		if enemy_node == null:
			continue
		parent.add_child(enemy_node)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(90.0, 200.0)
		enemy_node.global_position = global_position + offset
		if archetype != null:
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


# ========== 技能 4：蛛后束缚（全场 SNARE + SLOW）==========

func _trigger_bind() -> void:
	if _player == null:
		return
	# 全场 SNARE 3s
	_apply_snare_to_player(bind_snare_duration)
	# 额外 SLOW 延迟 2s（SNARE 结束后再 SLOW）
	var slow_timer := get_tree().create_timer(bind_snare_duration)
	slow_timer.timeout.connect(_apply_bind_slow)
	# 视觉警告圈
	_spawn_bind_warning()


func _apply_bind_slow() -> void:
	if not is_instance_valid(_player) or _is_dead:
		return
	if _player.has_method("apply_terrain_effect"):
		_player.call("apply_terrain_effect", TerrainEffect.Type.SLOW, bind_slow_duration)
	_slow_active = true
	_slow_remove_timer = bind_slow_duration


func _process_slow_timer(delta: float) -> void:
	if not _slow_active:
		return
	_slow_remove_timer -= delta
	if _slow_remove_timer <= 0.0:
		_slow_active = false
		if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
			_player.call("remove_terrain_effect", TerrainEffect.Type.SLOW)


func _spawn_bind_warning() -> void:
	if not is_instance_valid(_player):
		return
	var marker := Node2D.new()
	marker.name = "BindWarning"
	_get_effect_parent().add_child(marker)
	marker.global_position = _player.global_position

	var warn := Polygon2D.new()
	warn.color = Color(0.65, 0.3, 0.75, 0.38)
	warn.polygon = _make_circle_polygon(90.0, 28)
	marker.add_child(warn)

	var timer := get_tree().create_timer(bind_snare_duration + bind_slow_duration + 0.2)
	timer.timeout.connect(marker.queue_free)


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
			match str(t.get("type", "")):
				"silk":
					_detonate_silk(node, t["dir"] as Vector2)
				"poison":
					_detonate_poison(node)
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
	silk_damage *= enrage_damage_multiplier
	poison_dps *= enrage_damage_multiplier
	bind_damage *= enrage_damage_multiplier
	_silk_timer = minf(_silk_timer, silk_cooldown * enrage_cd_multiplier * 0.5)
	_poison_timer = minf(_poison_timer, poison_cooldown * enrage_cd_multiplier * 0.5)
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_cd_multiplier * 0.5)
	_bind_timer = minf(_bind_timer, bind_enraged_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.3, 0.6, 0.2, 1.0)
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
	if _snare_active and is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.SNARE)
	_snare_active = false
	if _slow_active and is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.SLOW)
	_slow_active = false


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
