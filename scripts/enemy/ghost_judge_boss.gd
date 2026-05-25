class_name GhostJudgeBoss
extends Enemy

## 鬼市判官 Boss（L002 B101）
##
## 技能：
##   - 召唤鬼差：每 6s 召唤 2-3 只 GhostOfficer，场上上限 8 只，圆周半径 80px
##   - 阵法封锁：每 5s 在玩家位置放置红圈，预警 1.2s 后引爆 22 伤害，半径 80
##   - 判决鸣鞭：每 4.5s 连发 3 枚投射物，间隔 0.3s，单发 12 伤害，速度 280
##   - 传送：每 8s 瞬移至玩家附近 350-400px，消失 0.5s，出现时爆裂 60px / 10 伤害
##
## 暴怒（HP 降至 35% 以下）：
##   - 移速 ×1.3，接触伤害 ×1.3，所有技能 CD ×0.65
##   - 身体变紫色，显示紫色光环
##
## 设计参考 docs/L002_GHOST_MARKET_DESIGN.md §3

enum BossState {
	CHASE,
	TELEPORT_OUT,
}

const GHOST_OFFICER_SCENE: PackedScene = preload("res://scenes/enemy/GhostOfficer.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy/EnemyProjectile.tscn")

# ---- 召唤鬼差 ----
@export var summon_cooldown: float = 6.0
@export var summon_batch_min: int = 2
@export var summon_batch_max: int = 3
@export var summon_max_alive: int = 8
@export var summon_spawn_radius: float = 80.0

# ---- 阵法封锁 ----
@export var zone_cooldown: float = 5.0
@export var zone_warning_time: float = 1.2
@export var zone_radius: float = 80.0
@export var zone_damage: float = 22.0
@export var zone_linger_time: float = 0.18

# ---- 判决鸣鞭 ----
@export var barrage_cooldown: float = 4.5
@export var barrage_count: int = 3
@export var barrage_interval: float = 0.3
@export var barrage_damage: float = 12.0
@export var barrage_speed: float = 280.0
@export var barrage_color: Color = Color(0.9, 0.85, 0.3, 0.9)

# ---- 传送 ----
@export var teleport_cooldown: float = 8.0
@export var teleport_disappear_time: float = 0.5
@export var teleport_distance_min: float = 350.0
@export var teleport_distance_max: float = 400.0
@export var teleport_burst_radius: float = 60.0
@export var teleport_burst_damage: float = 10.0

# ---- 暴怒 ----
@export var enrage_health_ratio: float = 0.35
@export var enrage_speed_multiplier: float = 1.3
@export var enrage_damage_multiplier: float = 1.3
@export var enrage_cd_multiplier: float = 0.65

# ---- 内部状态 ----
var _state: int = BossState.CHASE
var _state_timer: float = 0.0

var _summon_timer: float = 0.0
var _zone_timer: float = 0.0
var _barrage_timer: float = 0.0
var _teleport_timer: float = 0.0

var _is_enraged: bool = false

var _zone_markers: Array[Dictionary] = []
var _summoned_enemies: Array[Node] = []

var _pending_barrage_shots: int = 0
var _barrage_shot_timer: float = 0.0

var _is_invisible: bool = false

@onready var _enraged_aura: Polygon2D = $EnragedAura


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	xp_drop_value = 0.0

	# 参数安全校验
	summon_cooldown = maxf(summon_cooldown, 0.1)
	summon_batch_min = maxi(summon_batch_min, 1)
	summon_batch_max = maxi(summon_batch_max, summon_batch_min)
	summon_max_alive = maxi(summon_max_alive, 0)
	summon_spawn_radius = maxf(summon_spawn_radius, 8.0)
	zone_cooldown = maxf(zone_cooldown, 0.1)
	zone_warning_time = maxf(zone_warning_time, 0.05)
	zone_radius = maxf(zone_radius, 4.0)
	zone_damage = maxf(zone_damage, 0.0)
	zone_linger_time = maxf(zone_linger_time, 0.05)
	barrage_cooldown = maxf(barrage_cooldown, 0.1)
	barrage_count = maxi(barrage_count, 1)
	barrage_interval = maxf(barrage_interval, 0.05)
	barrage_damage = maxf(barrage_damage, 0.0)
	barrage_speed = maxf(barrage_speed, 0.0)
	teleport_cooldown = maxf(teleport_cooldown, 0.1)
	teleport_disappear_time = maxf(teleport_disappear_time, 0.05)
	teleport_distance_min = maxf(teleport_distance_min, 0.0)
	teleport_distance_max = maxf(teleport_distance_max, teleport_distance_min)
	teleport_burst_radius = maxf(teleport_burst_radius, 0.0)
	teleport_burst_damage = maxf(teleport_burst_damage, 0.0)
	enrage_health_ratio = clampf(enrage_health_ratio, 0.01, 0.99)
	enrage_speed_multiplier = maxf(enrage_speed_multiplier, 0.1)
	enrage_damage_multiplier = maxf(enrage_damage_multiplier, 0.0)
	enrage_cd_multiplier = clampf(enrage_cd_multiplier, 0.1, 1.0)

	# 错开各技能初始计时，避免开场同时触发
	_summon_timer = 4.0
	_zone_timer = 2.5
	_barrage_timer = 3.0
	_teleport_timer = 6.0

	if _enraged_aura != null:
		_enraged_aura.visible = false
		_enraged_aura.polygon = _make_circle_polygon(38.0, 28)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)

	_process_zone_markers(delta)
	_process_barrage_shots(delta)
	_process_summon_timer(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		BossState.CHASE:
			_process_chase(delta)
		BossState.TELEPORT_OUT:
			_process_teleport_out(delta)

	if not _is_invisible:
		_try_damage_player()


# ========== 状态处理 ==========

func _process_chase(delta: float) -> void:
	_zone_timer -= delta
	_barrage_timer -= delta
	_teleport_timer -= delta

	# 技能触发优先级：传送 > 阵法封锁 > 判决鸣鞭
	if _teleport_timer <= 0.0:
		_start_teleport_out()
		return

	if _zone_timer <= 0.0:
		_trigger_zone()
		_zone_timer = zone_cooldown * _get_cd_multiplier()

	if _barrage_timer <= 0.0 and _pending_barrage_shots <= 0:
		_start_barrage()
		_barrage_timer = barrage_cooldown * _get_cd_multiplier()

	# 慢速追击玩家
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * move_speed
	move_and_slide()


func _process_teleport_out(delta: float) -> void:
	_state_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if _state_timer <= 0.0:
		_do_teleport_in()


# ========== 技能：传送 ==========

func _start_teleport_out() -> void:
	_state = BossState.TELEPORT_OUT
	_state_timer = teleport_disappear_time
	_is_invisible = true
	_teleport_timer = teleport_cooldown * _get_cd_multiplier()
	if _body != null:
		_body.modulate = Color(0.5, 0.5, 0.8, 0.3)


func _do_teleport_in() -> void:
	var dist: float = randf_range(teleport_distance_min, teleport_distance_max)
	var angle: float = randf() * TAU
	global_position = _player.global_position + Vector2.RIGHT.rotated(angle) * dist

	_state = BossState.CHASE
	_is_invisible = false
	if _body != null:
		_body.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# 暴怒时维持紫色调
		if _is_enraged:
			_body.color = Color(0.7, 0.3, 0.9, 1.0)

	# 出现时对附近玩家造成爆裂伤害
	if is_instance_valid(_player):
		if _player.global_position.distance_to(global_position) <= teleport_burst_radius:
			if _player.has_method("take_damage"):
				_player.call("take_damage", teleport_burst_damage)


# ========== 技能：阵法封锁 ==========

func _trigger_zone() -> void:
	var target_pos := global_position
	if is_instance_valid(_player):
		target_pos = _player.global_position
	var marker := _create_zone_marker(target_pos)
	_zone_markers.append({
		"node": marker,
		"timer": zone_warning_time,
		"state": 0,
	})


func _create_zone_marker(pos: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.name = "GhostJudgeZoneMarker"
	_get_effect_parent().add_child(marker)
	marker.global_position = pos

	var warning := Polygon2D.new()
	warning.name = "Warning"
	warning.color = Color(0.6, 0.2, 0.8, 0.32)
	warning.polygon = _make_circle_polygon(zone_radius, 32)
	marker.add_child(warning)

	var explosion := Polygon2D.new()
	explosion.name = "Explosion"
	explosion.visible = false
	explosion.color = Color(0.9, 0.4, 1.0, 0.58)
	explosion.polygon = _make_circle_polygon(zone_radius * 1.05, 32)
	marker.add_child(explosion)

	return marker


func _process_zone_markers(delta: float) -> void:
	var index := _zone_markers.size() - 1
	while index >= 0:
		var zone := _zone_markers[index]
		var marker := zone["node"] as Node2D
		if not is_instance_valid(marker):
			_zone_markers.remove_at(index)
			index -= 1
			continue

		zone["timer"] = float(zone["timer"]) - delta
		if int(zone["state"]) == 0 and float(zone["timer"]) <= 0.0:
			_detonate_zone(marker)
			zone["state"] = 1
			zone["timer"] = zone_linger_time
		elif int(zone["state"]) == 1 and float(zone["timer"]) <= 0.0:
			marker.queue_free()
			_zone_markers.remove_at(index)

		index -= 1


func _detonate_zone(marker: Node2D) -> void:
	var warning := marker.get_node_or_null("Warning") as Polygon2D
	if warning != null:
		warning.visible = false

	var explosion := marker.get_node_or_null("Explosion") as Polygon2D
	if explosion != null:
		explosion.visible = true

	if is_instance_valid(_player) and _player.has_method("take_damage"):
		if _player.global_position.distance_to(marker.global_position) <= zone_radius:
			_player.call("take_damage", zone_damage)


# ========== 技能：判决鸣鞭（3 连发投射物）==========

func _start_barrage() -> void:
	_pending_barrage_shots = barrage_count
	_barrage_shot_timer = 0.0


func _process_barrage_shots(delta: float) -> void:
	if _pending_barrage_shots <= 0:
		return
	_barrage_shot_timer -= delta
	if _barrage_shot_timer <= 0.0:
		_fire_barrage_shot()
		_pending_barrage_shots -= 1
		_barrage_shot_timer = barrage_interval


func _fire_barrage_shot() -> void:
	if PROJECTILE_SCENE == null or not is_instance_valid(_player):
		return
	var proj_instance := PROJECTILE_SCENE.instantiate()
	if not proj_instance is EnemyProjectile:
		proj_instance.queue_free()
		return
	var proj := proj_instance as EnemyProjectile
	_get_effect_parent().add_child(proj)
	proj.global_position = global_position
	var direction := global_position.direction_to(_player.global_position)
	proj.setup(direction, barrage_speed, barrage_damage, barrage_color)


# ========== 技能：召唤鬼差 ==========

func _process_summon_timer(delta: float) -> void:
	_clean_summoned_enemies()
	_summon_timer -= delta
	if _summon_timer > 0.0:
		return
	_summon_timer = summon_cooldown * _get_cd_multiplier()
	_summon_officers()


func _summon_officers() -> void:
	var available := summon_max_alive - _summoned_enemies.size()
	if available <= 0:
		return
	var count := mini(randi_range(summon_batch_min, summon_batch_max), available)
	for i in range(count):
		_spawn_officer(i, count)


func _spawn_officer(index: int, total: int) -> void:
	if GHOST_OFFICER_SCENE == null:
		return
	var inst := GHOST_OFFICER_SCENE.instantiate()
	_get_effect_parent().add_child(inst)
	var angle: float = TAU * float(index) / float(maxi(total, 1))
	inst.global_position = global_position + Vector2.RIGHT.rotated(angle) * summon_spawn_radius
	if inst.has_signal("died"):
		inst.died.connect(_on_summoned_enemy_died)
	_summoned_enemies.append(inst)


func _clean_summoned_enemies() -> void:
	var index := _summoned_enemies.size() - 1
	while index >= 0:
		if not is_instance_valid(_summoned_enemies[index]):
			_summoned_enemies.remove_at(index)
		index -= 1


func _on_summoned_enemy_died(_enemy: Node) -> void:
	# 下一帧 _clean_summoned_enemies 会清理无效实例
	pass


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
	_summon_timer = minf(_summon_timer, summon_cooldown * enrage_cd_multiplier * 0.5)
	_zone_timer = minf(_zone_timer, zone_cooldown * enrage_cd_multiplier * 0.5)
	_barrage_timer = minf(_barrage_timer, barrage_cooldown * enrage_cd_multiplier * 0.5)
	_teleport_timer = minf(_teleport_timer, teleport_cooldown * enrage_cd_multiplier * 0.5)
	if _body != null:
		_body.color = Color(0.7, 0.3, 0.9, 1.0)
	if _enraged_aura != null:
		_enraged_aura.visible = true


func _get_cd_multiplier() -> float:
	if _is_enraged:
		return enrage_cd_multiplier
	return 1.0


# ========== 死亡清场 ==========

func _die() -> void:
	# 清除场上召唤物
	for enemy in _summoned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_summoned_enemies.clear()

	# 清除阵法标记
	for zone in _zone_markers:
		var node = zone["node"]
		if is_instance_valid(node):
			node.queue_free()
	_zone_markers.clear()

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
