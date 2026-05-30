class_name NiuMoWangBoss
extends Enemy

## 牛魔王 B401（L005 五·火焰山）
##
## 设计 §3 L005：4 技能套餐：
## - 技能 1 铁牛冲撞（cd 3.5s）：蓄力 0.9s 红线预警 → 直线冲刺 0.5s/32dmg
## - 技能 2 烈焰踏地（cd 5.5s）：玩家周围 5 点生成 BURN TerrainEffect 区 4s/6dps
## - 技能 3 唤召火灵（cd 7s）：5 只 E401 fire_spirit
## - 技能 4 熔岩爆发（cd 12s / 暴怒 8s）：外扩岩浆环 280px/30dmg + 自身 BURN 区 3s
## 暴怒（35% HP）：cd×0.65 速×1.35 伤×1.25
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L005

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
const FIRE_SPIRIT_ARCHETYPE: Resource = preload("res://resources/enemies/fire_spirit.tres")
const TERRAIN_EFFECT_SCENE: PackedScene = preload("res://scenes/system/TerrainEffect.tscn")

enum BossState {
	CHASE,
	CHARGE_WINDUP,
	CHARGE,
	CHARGE_RECOVERY,
}

# 技能 1 铁牛冲撞
@export var charge_cooldown: float = 3.5
@export var charge_windup_time: float = 0.9
@export var charge_duration: float = 0.5
@export var charge_recovery_time: float = 0.35
@export var charge_speed: float = 350.0
@export var charge_damage: float = 32.0
@export var charge_warning_length: float = 280.0
@export var charge_warning_width: float = 50.0

# 技能 2 烈焰踏地
@export var stomp_cooldown: float = 5.5
@export var stomp_warning_time: float = 0.8
@export var stomp_count: int = 5
@export var stomp_burn_radius: float = 48.0
@export var stomp_burn_duration: float = 4.0
@export var stomp_burn_dps: float = 6.0
@export var stomp_spread: float = 180.0

# 技能 3 唤召火灵
@export var summon_cooldown: float = 7.0
@export var summon_count: int = 5

# 技能 4 熔岩爆发
@export var lava_burst_cooldown: float = 12.0
@export var lava_burst_warning_time: float = 0.9
@export var lava_burst_radius: float = 280.0
@export var lava_burst_damage: float = 30.0
@export var lava_self_burn_radius: float = 80.0
@export var lava_self_burn_duration: float = 3.0

# 暴怒
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.35
@export var enrage_damage_multiplier: float = 1.25
@export var enrage_cd_multiplier: float = 0.65

var _state: int = BossState.CHASE
var _state_timer: float = 0.0
var _charge_timer: float = 0.0
var _stomp_timer: float = 0.0
var _summon_timer: float = 0.0
var _lava_burst_timer: float = 0.0
var _charge_direction: Vector2 = Vector2.RIGHT
var _is_enraged: bool = false
var _burst_markers: Array[Dictionary] = []
var _charge_hit_players: bool = false

@onready var _charge_telegraph: Line2D = $ChargeTelegraph
@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	charge_cooldown = maxf(charge_cooldown, 0.1)
	charge_windup_time = maxf(charge_windup_time, 0.05)
	charge_duration = maxf(charge_duration, 0.05)
	charge_recovery_time = maxf(charge_recovery_time, 0.0)
	charge_speed = maxf(charge_speed, 0.0)
	charge_damage = maxf(charge_damage, 0.0)
	charge_warning_length = maxf(charge_warning_length, 8.0)
	stomp_cooldown = maxf(stomp_cooldown, 0.1)
	stomp_warning_time = maxf(stomp_warning_time, 0.05)
	stomp_count = maxi(stomp_count, 1)
	stomp_burn_radius = maxf(stomp_burn_radius, 8.0)
	stomp_burn_duration = maxf(stomp_burn_duration, 0.1)
	stomp_burn_dps = maxf(stomp_burn_dps, 0.0)
	stomp_spread = maxf(stomp_spread, 8.0)
	summon_cooldown = maxf(summon_cooldown, 0.1)
	summon_count = maxi(summon_count, 0)
	lava_burst_cooldown = maxf(lava_burst_cooldown, 0.1)
	lava_burst_warning_time = maxf(lava_burst_warning_time, 0.05)
	lava_burst_radius = maxf(lava_burst_radius, 8.0)
	lava_burst_damage = maxf(lava_burst_damage, 0.0)
	lava_self_burn_radius = maxf(lava_self_burn_radius, 8.0)
	lava_self_burn_duration = maxf(lava_self_burn_duration, 0.1)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_charge_timer = 2.0
	_stomp_timer = 4.5
	_summon_timer = 6.0
	_lava_burst_timer = 9.0

	if _charge_telegraph != null:
		_charge_telegraph.visible = false
	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(60.0, 32)


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

	match _state:
		BossState.CHASE:
			_process_chase(delta)
		BossState.CHARGE_WINDUP:
			_process_charge_windup(delta)
		BossState.CHARGE:
			_process_charge(delta)
		BossState.CHARGE_RECOVERY:
			_process_charge_recovery(delta)

	_try_damage_player()


# ========== 状态机 ==========

func _process_chase(delta: float) -> void:
	_charge_timer -= delta
	_stomp_timer -= delta
	_summon_timer -= delta
	_lava_burst_timer -= delta

	# 技能触发优先级：熔岩爆发 > 召唤 > 踏地 > 冲撞
	if _lava_burst_timer <= 0.0:
		_trigger_lava_burst()
		_lava_burst_timer = lava_burst_cooldown * _get_cd_multiplier()
	elif _summon_timer <= 0.0:
		_trigger_summon()
		_summon_timer = summon_cooldown * _get_cd_multiplier()
	elif _stomp_timer <= 0.0:
		_trigger_stomp()
		_stomp_timer = stomp_cooldown * _get_cd_multiplier()
	elif _charge_timer <= 0.0:
		_start_charge_windup()
		return

	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()


func _process_charge_windup(delta: float) -> void:
	_update_charge_direction()
	_state_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_start_charge()


func _process_charge(delta: float) -> void:
	_state_timer -= delta
	velocity = _charge_direction * charge_speed
	move_and_slide()
	# 冲撞期间检测玩家碰撞
	if not _charge_hit_players and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist <= 48.0:
			if _player.has_method("take_damage"):
				_player.call("take_damage", charge_damage)
			_charge_hit_players = true
	if _state_timer <= 0.0:
		_start_charge_recovery()


func _process_charge_recovery(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_state = BossState.CHASE


func _start_charge_windup() -> void:
	_state = BossState.CHARGE_WINDUP
	_state_timer = charge_windup_time
	_charge_timer = charge_cooldown * _get_cd_multiplier()
	_charge_hit_players = false
	_update_charge_direction()
	if _charge_telegraph != null:
		_charge_telegraph.visible = true


func _start_charge() -> void:
	_state = BossState.CHARGE
	_state_timer = charge_duration
	if _charge_telegraph != null:
		_charge_telegraph.visible = false


func _start_charge_recovery() -> void:
	_state = BossState.CHARGE_RECOVERY
	_state_timer = charge_recovery_time
	velocity = Vector2.ZERO


func _update_charge_direction() -> void:
	if is_instance_valid(_player):
		var dir := global_position.direction_to(_player.global_position)
		if dir != Vector2.ZERO:
			_charge_direction = dir
	if _charge_telegraph != null:
		_charge_telegraph.points = PackedVector2Array([
			Vector2.ZERO,
			_charge_direction * charge_warning_length,
		])


# ========== 技能 2：烈焰踏地（多点 BURN 区）==========

func _trigger_stomp() -> void:
	if _player == null:
		return
	for i in range(stomp_count):
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, stomp_spread)
		var pos := _player.global_position + offset
		_spawn_stomp_marker(pos)


func _spawn_stomp_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.name = "StompMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(0.9, 0.4, 0.05, 0.38)
	warn.polygon = _make_circle_polygon(stomp_burn_radius, 20)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": stomp_warning_time,
		"state": 0,
		"radius": stomp_burn_radius,
		"is_stomp": true,
	})


# ========== 技能 3：唤召火灵 ==========

func _trigger_summon() -> void:
	if FIRE_SPIRIT_ARCHETYPE == null or ENEMY_SCENE == null:
		return
	for i in range(summon_count):
		var enemy_node := ENEMY_SCENE.instantiate()
		if enemy_node == null:
			continue
		var parent := _get_effect_parent()
		parent.add_child(enemy_node)
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 180.0)
		enemy_node.global_position = global_position + offset
		# 应用火灵 archetype 数值（duck typing）
		if "max_hp" in enemy_node:
			enemy_node.max_hp = FIRE_SPIRIT_ARCHETYPE.max_hp
		if "current_hp" in enemy_node:
			enemy_node.current_hp = FIRE_SPIRIT_ARCHETYPE.max_hp
		if "move_speed" in enemy_node:
			enemy_node.move_speed = FIRE_SPIRIT_ARCHETYPE.move_speed
		if "damage" in enemy_node:
			enemy_node.damage = FIRE_SPIRIT_ARCHETYPE.damage
		if "xp_drop_value" in enemy_node:
			enemy_node.xp_drop_value = FIRE_SPIRIT_ARCHETYPE.xp_drop_value
		if "_body" in enemy_node and is_instance_valid(enemy_node._body):
			enemy_node._body.color = FIRE_SPIRIT_ARCHETYPE.body_color


# ========== 技能 4：熔岩爆发（岩浆环 + 自身 BURN 区）==========

func _trigger_lava_burst() -> void:
	if _player == null:
		return
	# 生成岩浆环扩散预警标记
	_spawn_lava_ring_marker()
	# 在自身位置生成 BURN 区
	_spawn_burn_at(global_position, lava_self_burn_radius, lava_self_burn_duration)


func _spawn_lava_ring_marker() -> void:
	var marker := Node2D.new()
	marker.name = "LavaRingMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = global_position

	var warn := Polygon2D.new()
	warn.name = "Warning"
	warn.color = Color(1.0, 0.35, 0.05, 0.35)
	warn.polygon = _make_ring_polygon(lava_burst_radius - 20.0, lava_burst_radius, 32)
	marker.add_child(warn)

	_burst_markers.append({
		"node": marker,
		"timer": lava_burst_warning_time,
		"state": 0,
		"radius": lava_burst_radius,
		"is_stomp": false,
	})


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
			_detonate_burst(node, float(t["radius"]), bool(t["is_stomp"]))
			t["state"] = 1
			t["timer"] = 0.18
		elif int(t["state"]) == 1 and float(t["timer"]) <= 0.0:
			node.queue_free()
			_burst_markers.remove_at(i)
		i -= 1


func _detonate_burst(marker: Node2D, radius: float, is_stomp: bool) -> void:
	var warn := marker.get_node_or_null("Warning") as Polygon2D
	if warn != null:
		warn.visible = false
	# 爆炸闪光
	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.5, 0.1, 0.7)
	flash.polygon = _make_circle_polygon(radius * 1.05, 20)
	marker.add_child(flash)

	if is_instance_valid(_player):
		if _player.global_position.distance_to(marker.global_position) <= radius:
			if _player.has_method("take_damage"):
				var dmg := lava_burst_damage if not is_stomp else 0.0
				if dmg > 0.0:
					_player.call("take_damage", dmg)

	# 踏地落点生成小 BURN 区
	if is_stomp:
		_spawn_burn_at(marker.global_position, stomp_burn_radius, stomp_burn_duration)


# ========== BURN 区生成 helper ==========

func _spawn_burn_at(pos: Vector2, radius: float, duration: float) -> void:
	if TERRAIN_EFFECT_SCENE == null:
		return
	var te = TERRAIN_EFFECT_SCENE.instantiate()
	if te == null:
		return
	te.effect_type = TerrainEffect.Type.BURN
	te.effect_radius = radius
	te.burn_dps = stomp_burn_dps
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
	charge_damage *= enrage_damage_multiplier
	lava_burst_damage *= enrage_damage_multiplier
	stomp_burn_dps *= enrage_damage_multiplier
	# 收紧各计时器到暴怒 CD 上限
	_charge_timer = minf(_charge_timer, charge_cooldown * enrage_cd_multiplier * 0.5)
	_stomp_timer = minf(_stomp_timer, stomp_cooldown * enrage_cd_multiplier * 0.5)
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_cd_multiplier * 0.5)
	_lava_burst_timer = minf(_lava_burst_timer, lava_burst_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(1.0, 0.25, 0.05, 1.0)
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
	if _charge_telegraph != null:
		_charge_telegraph.visible = false
	super._die()


# ========== 工具函数 ==========

func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in maxi(point_count, 3):
		var angle := TAU * float(i) / float(maxi(point_count, 3))
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _make_ring_polygon(inner_r: float, outer_r: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n := maxi(point_count, 6)
	# 外环顺时针
	for i in range(n):
		var angle := TAU * float(i) / float(n)
		points.append(Vector2.RIGHT.rotated(angle) * outer_r)
	# 内环逆时针（形成环形多边形）
	for i in range(n):
		var angle := TAU * float(n - 1 - i) / float(n)
		points.append(Vector2.RIGHT.rotated(angle) * inner_r)
	return points


func _get_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	var par := get_parent()
	if par != null:
		return par
	return self
