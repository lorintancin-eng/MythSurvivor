class_name StageDirector
extends Node2D

signal stage_time_changed(elapsed_time: float, stage_duration: float)
signal boss_warning_started(warning_lead_time: float)
signal boss_spawned(boss: Enemy)
signal elite_spawned(elite: Enemy, affixes: Array[String])
signal demon_seal_spawned(demon_seal: Area2D)
signal demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool)
signal demon_seal_completed(demon_seal: Area2D)
signal stage_cleared(elapsed_time: float)
signal stage_failed(elapsed_time: float)
signal boss_died(elapsed_time: float)

const DEFAULT_BOSS_SCENE: PackedScene = preload("res://scenes/enemy/FamineBeastBoss.tscn")
const DEFAULT_DEMON_SEAL_SCENE: PackedScene = preload("res://scenes/system/DemonSeal.tscn")
const DEFAULT_EXPERIENCE_ORB_SCENE: PackedScene = preload("res://scenes/system/ExperienceOrb.tscn")
const WANDERING_SOUL_ARCHETYPE: Resource = preload("res://resources/enemies/wandering_soul.tres")
const PAPER_DOLL_ARCHETYPE: Resource = preload("res://resources/enemies/paper_doll.tres")
const FOX_SPIRIT_ARCHETYPE: Resource = preload("res://resources/enemies/fox_spirit.tres")
const STONE_GOLEM_ARCHETYPE: Resource = preload("res://resources/enemies/stone_golem.tres")
const GHOST_FLAME_ARCHETYPE: Resource = preload("res://resources/enemies/ghost_flame.tres")
const SHANXIAO_ELITE_ARCHETYPE: Resource = preload("res://resources/enemies/shanxiao_elite.tres")
const MIN_STAGE_DURATION: float = 1.0
const MIN_SPAWN_DISTANCE: float = 80.0
const ELITE_AFFIX_IRON_BONES: String = "iron_bones"
const ELITE_AFFIX_SWIFT: String = "swift"
## v0.2 fallback wave 时间节点（stage_config 未设置时使用）
const WAVE_TWO_START_TIME: float = 60.0
const WAVE_THREE_START_TIME: float = 120.0
const WAVE_FOUR_START_TIME: float = 180.0
const WAVE_BOSS_WARNING_START_TIME: float = 270.0

## 关卡配置资源（v0.5 新增）
## 如果设置则覆盖所有 @export 默认值；未设置时沿用 @export 默认（v0.2 兼容路径）
@export var stage_config: StageConfig

@export var player_path: NodePath = ^"../Player"
@export var enemy_spawner_path: NodePath = ^"../EnemySpawner"
@export var boss_scene: PackedScene = DEFAULT_BOSS_SCENE
@export var demon_seal_scene: PackedScene = DEFAULT_DEMON_SEAL_SCENE
@export var experience_orb_scene: PackedScene = DEFAULT_EXPERIENCE_ORB_SCENE
@export var stage_duration: float = 300.0
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
@export var boss_move_speed: float = 70.0
@export var boss_max_hp: float = 260.0
@export var boss_damage: float = 16.0
@export var boss_scale: float = 1.8
@export var boss_phase_spawn_interval: float = 2.5
@export var boss_phase_max_enemies: int = 8
@export var demon_seal_spawn_time: float = 120.0
@export var demon_seal_min_spawn_distance: float = 200.0
@export var demon_seal_max_spawn_distance: float = 280.0
@export var demon_seal_required_seconds: float = 8.0
@export var demon_seal_pressure_interval_multiplier: float = 0.65
@export var demon_seal_pressure_max_enemy_bonus: int = 6
@export var demon_seal_reward_orb_count: int = 8
@export var demon_seal_reward_xp_value: float = 6.0
@export var demon_seal_reward_radius: float = 54.0
@export var first_elite_spawn_time: float = 180.0
@export var second_elite_spawn_time: float = 240.0
@export var elite_spawn_distance: float = 420.0

# ─────────────────────────────────────────────
# DEBUG/QA：测试加速参数（默认 1.0 不影响正式游戏）
# 调小 spawn_interval_multiplier（如 0.3）→ 出怪间隔变 3x 短，敌人更密
# 调大 max_enemies_multiplier（如 2.0）→ 场上敌人上限翻倍
# 用于 W214 QA 快速观察战斗体验，测试完务必改回 1.0
# ─────────────────────────────────────────────
@export_group("Debug / QA Test")
@export var spawn_interval_multiplier: float = 1.0
@export var max_enemies_multiplier: float = 1.0
@export_group("")

var elapsed_time: float = 0.0

var _is_boss_warning_started: bool = false
var _is_boss_spawned: bool = false
var _is_demon_seal_spawned: bool = false
var _is_demon_seal_completed: bool = false
var _is_first_elite_spawned: bool = false
var _is_second_elite_spawned: bool = false
var _is_stage_cleared: bool = false
var _is_stage_failed: bool = false
var _is_demon_seal_pressure_active: bool = false
var _current_wave_config_index: int = -1
var _rng := RandomNumberGenerator.new()
var _player: Player
var _enemy_spawner: EnemySpawner
var _demon_seal: Area2D
var _stage_transition: Node = null


func _ready() -> void:
	_rng.randomize()
	_apply_config_values()

	_player = get_node_or_null(player_path) as Player
	_enemy_spawner = get_node_or_null(enemy_spawner_path) as EnemySpawner
	if _player != null and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_apply_current_wave_config(true)

	stage_time_changed.emit(elapsed_time, stage_duration)
	_setup_stage_transition()


func _process(delta: float) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	elapsed_time = minf(elapsed_time + delta, stage_duration)
	stage_time_changed.emit(elapsed_time, stage_duration)
	_apply_current_wave_config()

	if not _is_boss_warning_started and elapsed_time >= stage_duration - boss_warning_lead_time:
		_is_boss_warning_started = true
		boss_warning_started.emit(boss_warning_lead_time)

	if not _is_demon_seal_spawned and elapsed_time >= demon_seal_spawn_time:
		_spawn_demon_seal()

	if not _is_first_elite_spawned and elapsed_time >= first_elite_spawn_time:
		_spawn_first_elite()

	if not _is_second_elite_spawned and elapsed_time >= second_elite_spawn_time:
		_spawn_second_elite()

	if not _is_boss_spawned and elapsed_time >= stage_duration:
		_spawn_boss()


## 优先返回 stage_config 字段值，回退到 @export 默认值
## 用于在 _ready 中读取并覆盖 @export 字段
func _get_config_value(field_name: String, fallback: Variant) -> Variant:
	if stage_config != null:
		var value: Variant = stage_config.get(field_name)
		if value != null:
			return value
	return fallback


func _spawn_demon_seal() -> void:
	_is_demon_seal_spawned = true
	var eff_demon_seal_scene: PackedScene
	if stage_config != null and stage_config.demon_seal_scene != null:
		eff_demon_seal_scene = stage_config.demon_seal_scene
	else:
		eff_demon_seal_scene = demon_seal_scene

	if eff_demon_seal_scene == null:
		push_warning("StageDirector has no demon_seal_scene.")
		return

	var seal_instance := eff_demon_seal_scene.instantiate()
	if not seal_instance is Area2D:
		push_error("StageDirector demon_seal_scene must instantiate an Area2D.")
		seal_instance.queue_free()
		return

	_demon_seal = seal_instance as Area2D
	if not _demon_seal.has_signal(&"seal_progress_changed") or not _demon_seal.has_signal(&"seal_completed"):
		push_error("StageDirector demon_seal_scene must provide seal progress and completed signals.")
		_demon_seal.queue_free()
		_demon_seal = null
		return

	_demon_seal.set("required_seconds", demon_seal_required_seconds)
	_demon_seal.connect(&"seal_progress_changed", _on_demon_seal_progress_changed)
	_demon_seal.connect(&"seal_completed", _on_demon_seal_completed)

	_get_spawn_parent().add_child(_demon_seal)
	_demon_seal.global_position = _get_demon_seal_spawn_position()
	demon_seal_spawned.emit(_demon_seal)


func _spawn_boss() -> void:
	_is_boss_spawned = true
	_apply_boss_phase_spawn_pressure()

	var eff_boss_scene: PackedScene
	if stage_config != null and stage_config.boss_scene != null:
		eff_boss_scene = stage_config.boss_scene
	elif boss_scene != null:
		eff_boss_scene = boss_scene
	else:
		eff_boss_scene = DEFAULT_BOSS_SCENE

	if eff_boss_scene == null:
		push_warning("StageDirector has no boss_scene.")
		return

	var boss_instance := eff_boss_scene.instantiate()
	if not boss_instance is Enemy:
		push_error("StageDirector boss_scene must instantiate an Enemy.")
		boss_instance.queue_free()
		return

	var boss := boss_instance as Enemy
	boss.name = "FamineBeastBoss"
	if boss.archetype == null:
		boss.move_speed = boss_move_speed
		boss.max_hp = boss_max_hp
		boss.damage = boss_damage
		boss.scale = Vector2.ONE * boss_scale
	boss.xp_drop_value = 0.0
	boss.died.connect(_on_boss_died)

	_get_spawn_parent().add_child(boss)
	boss.global_position = _get_boss_spawn_position()
	boss_spawned.emit(boss)


func _spawn_first_elite() -> void:
	_is_first_elite_spawned = true
	_spawn_shanxiao_elite([ELITE_AFFIX_IRON_BONES])


func _spawn_second_elite() -> void:
	_is_second_elite_spawned = true
	_spawn_shanxiao_elite([ELITE_AFFIX_SWIFT])


func _spawn_shanxiao_elite(affixes: Array[String]) -> void:
	if _enemy_spawner == null:
		push_warning("StageDirector could not find EnemySpawner for elite spawn.")
		return

	var elite := _enemy_spawner.spawn_elite_at(
		SHANXIAO_ELITE_ARCHETYPE,
		_get_elite_spawn_position(),
		affixes
	)
	if elite != null:
		elite_spawned.emit(elite, affixes)


func _apply_boss_phase_spawn_pressure() -> void:
	if _enemy_spawner == null:
		return

	_enemy_spawner.spawn_interval = maxf(_enemy_spawner.spawn_interval, boss_phase_spawn_interval)
	if boss_phase_max_enemies >= 0:
		_enemy_spawner.max_enemies = mini(_enemy_spawner.max_enemies, boss_phase_max_enemies)


func _apply_current_wave_config(force_apply: bool = false) -> void:
	if _enemy_spawner == null or _is_boss_spawned:
		return

	var wave_config_index := _get_wave_config_index()
	if not force_apply and wave_config_index == _current_wave_config_index:
		return

	_current_wave_config_index = wave_config_index
	var wave_spawn_interval := _get_wave_spawn_interval(wave_config_index)
	var wave_max_enemies := _get_wave_max_enemies(wave_config_index)
	if _is_demon_seal_pressure_active:
		wave_spawn_interval = maxf(wave_spawn_interval * demon_seal_pressure_interval_multiplier, 0.1)
		wave_max_enemies += demon_seal_pressure_max_enemy_bonus

	# DEBUG/QA：应用测试加速倍率（默认 1.0 / 1.0 不改变行为）
	wave_spawn_interval = maxf(wave_spawn_interval * maxf(spawn_interval_multiplier, 0.01), 0.1)
	wave_max_enemies = maxi(int(round(float(wave_max_enemies) * maxf(max_enemies_multiplier, 0.1))), 1)

	_enemy_spawner.apply_wave_config(
		wave_spawn_interval,
		wave_max_enemies,
		_get_wave_archetype_pool(wave_config_index),
		_get_wave_archetype_weights(wave_config_index)
	)


func _get_wave_config_index() -> int:
	var boss_warning_time: float
	var wave_four_time: float
	var wave_three_time: float
	var wave_two_time: float

	if stage_config != null:
		boss_warning_time = stage_config.wave_boss_warning_start_time
		wave_four_time = stage_config.wave_four_start_time
		wave_three_time = stage_config.wave_three_start_time
		wave_two_time = stage_config.wave_two_start_time
	else:
		boss_warning_time = WAVE_BOSS_WARNING_START_TIME
		wave_four_time = WAVE_FOUR_START_TIME
		wave_three_time = WAVE_THREE_START_TIME
		wave_two_time = WAVE_TWO_START_TIME

	if elapsed_time >= boss_warning_time:
		return 4
	if elapsed_time >= wave_four_time:
		return 3
	if elapsed_time >= wave_three_time:
		return 2
	if elapsed_time >= wave_two_time:
		return 1

	return 0


func _get_wave_spawn_interval(wave_config_index: int) -> float:
	if stage_config != null and stage_config.wave_spawn_intervals.size() > wave_config_index:
		return stage_config.wave_spawn_intervals[wave_config_index]
	# Fallback: 沿用 v0.2 硬编码
	match wave_config_index:
		0:
			return 1.35
		1:
			return 1.08
		2:
			return 0.90
		3:
			return 0.72
		_:
			return 0.55


func _get_wave_max_enemies(wave_config_index: int) -> int:
	if stage_config != null and stage_config.wave_max_enemies.size() > wave_config_index:
		return stage_config.wave_max_enemies[wave_config_index]
	# Fallback: 沿用 v0.2 硬编码
	match wave_config_index:
		0:
			return 18
		1:
			return 24
		2:
			return 32
		3:
			return 42
		_:
			return 56


func _get_wave_archetype_pool(wave_config_index: int) -> Array[Resource]:
	if stage_config != null and stage_config.wave_pools.size() > wave_config_index:
		var pool := stage_config.wave_pools[wave_config_index]
		if pool != null:
			return pool.archetypes.duplicate()
	# Fallback: 沿用 v0.2 硬编码
	match wave_config_index:
		0:
			return [
				PAPER_DOLL_ARCHETYPE,
				WANDERING_SOUL_ARCHETYPE,
			]
		1:
			return [
				PAPER_DOLL_ARCHETYPE,
				WANDERING_SOUL_ARCHETYPE,
				FOX_SPIRIT_ARCHETYPE,
				GHOST_FLAME_ARCHETYPE,
			]
		_:
			return [
				PAPER_DOLL_ARCHETYPE,
				WANDERING_SOUL_ARCHETYPE,
				FOX_SPIRIT_ARCHETYPE,
				GHOST_FLAME_ARCHETYPE,
				STONE_GOLEM_ARCHETYPE,
			]


func _get_wave_archetype_weights(wave_config_index: int) -> Array[float]:
	if stage_config != null and stage_config.wave_pools.size() > wave_config_index:
		var pool := stage_config.wave_pools[wave_config_index]
		if pool != null:
			return pool.weights.duplicate()
	# Fallback: 沿用 v0.2 硬编码
	match wave_config_index:
		0:
			return [4.0, 3.0]
		1:
			return [3.6, 3.0, 0.8, 0.6]
		2:
			return [2.8, 2.8, 1.2, 1.0, 0.35]
		3:
			return [2.5, 2.4, 1.8, 1.4, 0.7]
		_:
			return [2.0, 2.0, 2.3, 1.9, 1.0]


func _set_demon_seal_pressure_active(is_active: bool) -> void:
	if _enemy_spawner == null:
		return
	if is_active == _is_demon_seal_pressure_active:
		return

	_is_demon_seal_pressure_active = is_active
	if _is_boss_spawned:
		_apply_boss_phase_spawn_pressure()
		return

	_apply_current_wave_config(true)


func _get_spawn_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self


func _get_boss_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	return player_position + Vector2.RIGHT.rotated(angle) * boss_spawn_distance


func _get_demon_seal_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(demon_seal_min_spawn_distance, demon_seal_max_spawn_distance)
	var base_pos := player_position + Vector2.RIGHT.rotated(angle) * distance
	var jitter := Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-30.0, 30.0))
	return base_pos + jitter


func _get_elite_spawn_position() -> Vector2:
	var player_position := global_position
	if is_instance_valid(_player):
		player_position = _player.global_position

	var angle := _rng.randf_range(0.0, TAU)
	return player_position + Vector2.RIGHT.rotated(angle) * elite_spawn_distance


func _spawn_demon_seal_reward(center_position: Vector2) -> void:
	var eff_experience_orb_scene: PackedScene
	if stage_config != null and stage_config.experience_orb_scene != null:
		eff_experience_orb_scene = stage_config.experience_orb_scene
	else:
		eff_experience_orb_scene = experience_orb_scene

	if eff_experience_orb_scene == null:
		push_warning("StageDirector has no experience_orb_scene.")
		return

	for index in demon_seal_reward_orb_count:
		var orb_instance := eff_experience_orb_scene.instantiate()
		if not orb_instance is ExperienceOrb:
			push_error("StageDirector experience_orb_scene must instantiate an ExperienceOrb.")
			orb_instance.queue_free()
			return

		var orb := orb_instance as ExperienceOrb
		orb.xp_value = demon_seal_reward_xp_value
		_get_spawn_parent().add_child(orb)

		var angle := TAU * float(index) / float(maxi(demon_seal_reward_orb_count, 1))
		var distance := demon_seal_reward_radius
		if demon_seal_reward_orb_count == 1:
			distance = 0.0
		orb.global_position = center_position + Vector2.RIGHT.rotated(angle) * distance


func _on_demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool) -> void:
	if _is_stage_cleared or _is_stage_failed or _is_demon_seal_completed:
		return

	_set_demon_seal_pressure_active(is_sealing)
	demon_seal_progress_changed.emit(progress_seconds, required_seconds, is_sealing)


func _on_demon_seal_completed(demon_seal: Area2D) -> void:
	if _is_demon_seal_completed:
		return

	_is_demon_seal_completed = true
	_set_demon_seal_pressure_active(false)
	_spawn_demon_seal_reward(demon_seal.global_position)
	demon_seal_completed.emit(demon_seal)


func _on_boss_died(_boss: Enemy) -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_cleared = true
	_set_demon_seal_pressure_active(false)
	if _enemy_spawner != null:
		_enemy_spawner.set_spawning_enabled(false)
	stage_cleared.emit(elapsed_time)
	boss_died.emit(elapsed_time)
	# F01: 延迟 1.5s 后尝试启动关卡过渡
	_trigger_stage_transition_after_delay()


func _on_player_died() -> void:
	if _is_stage_cleared or _is_stage_failed:
		return

	_is_stage_failed = true
	_set_demon_seal_pressure_active(false)
	stage_failed.emit(elapsed_time)


# ─────────────────────────────────────────────
# F01 / F02 关卡过渡
# ─────────────────────────────────────────────

## 在 _ready 末尾调用，动态实例化 StageTransition 节点并接线信号
func _setup_stage_transition() -> void:
	var transition_packed: PackedScene = load("res://scenes/ui/StageTransition.tscn") as PackedScene
	if transition_packed == null:
		push_warning("StageDirector: cannot load StageTransition.tscn")
		return
	var transition := transition_packed.instantiate()
	get_parent().add_child.call_deferred(transition)
	transition.transition_midpoint.connect(_on_transition_midpoint)
	transition.transition_completed.connect(_on_transition_completed)
	_stage_transition = transition


## Boss 死亡后等待 1.5s，让玩家看到通关结算，再启动过渡
func _trigger_stage_transition_after_delay() -> void:
	await get_tree().create_timer(1.5).timeout
	var current_stage_id := "stage_01_huangshan"
	if stage_config != null and stage_config.stage_id != "":
		current_stage_id = stage_config.stage_id
	var next_stage_id := StageRegistry.get_next_stage_id(current_stage_id)
	if next_stage_id == "":
		return
	if _stage_transition != null and _stage_transition.has_method("start_transition"):
		_stage_transition.start_transition(next_stage_id)
	else:
		push_warning("StageDirector: StageTransition not ready, skipping transition to %s" % next_stage_id)


## 过渡中点：清场 + 热切换到新关卡配置
func _on_transition_midpoint(next_stage_id: String) -> void:
	var next_config := StageRegistry.get_stage(next_stage_id)
	if next_config == null:
		push_warning("StageDirector: cannot load stage %s, aborting transition" % next_stage_id)
		return
	load_stage_config(next_config)


## 过渡完成回调（当前无需额外操作）
func _on_transition_completed(_next_stage_id: String) -> void:
	pass


## F01/F02：热切换到新关卡配置（不重建场景，玩家状态全保留）
## 由过渡中点回调触发
func load_stage_config(new_config: StageConfig) -> void:
	if new_config == null:
		push_warning("StageDirector.load_stage_config: null config")
		return

	# 1. 清场：所有敌人 / 经验球 / 镇妖碑
	_clear_active_objects()

	# 2. 重置内部状态
	elapsed_time = 0.0
	_is_boss_warning_started = false
	_is_boss_spawned = false
	_is_demon_seal_spawned = false
	_is_demon_seal_completed = false
	_is_first_elite_spawned = false
	_is_second_elite_spawned = false
	_is_stage_cleared = false
	_is_stage_failed = false
	_is_demon_seal_pressure_active = false
	_current_wave_config_index = -1

	# 3. 写入新 config 并重新计算所有 eff_* 字段
	stage_config = new_config
	_apply_config_values()

	# 4. 触发首波 wave，恢复出怪
	if _enemy_spawner != null:
		_enemy_spawner.set_spawning_enabled(true)
	_apply_current_wave_config(true)
	stage_time_changed.emit(elapsed_time, stage_duration)

	# F02：通知玩家新关卡开始（重置技能 cooldown），方法不存在则静默跳过
	if _player != null and _player.has_method("on_stage_transition"):
		_player.call("on_stage_transition")


## 清场：销毁所有敌人 / 经验球 / 镇妖碑
func _clear_active_objects() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	for seal in get_tree().get_nodes_in_group("demon_seals"):
		if is_instance_valid(seal):
			seal.queue_free()
	for orb in get_tree().get_nodes_in_group("experience_orbs"):
		if is_instance_valid(orb):
			orb.queue_free()
	if is_instance_valid(_demon_seal):
		_demon_seal.queue_free()
	_demon_seal = null


## 把 _ready 中所有 eff_* 计算 + 写回 @export 字段的逻辑提取到此函数
## _ready() 与 load_stage_config() 均调用此函数以保持一致
func _apply_config_values() -> void:
	var eff_stage_duration := _get_config_value("stage_duration", stage_duration) as float
	eff_stage_duration = maxf(eff_stage_duration, MIN_STAGE_DURATION)

	var eff_boss_warning_lead_time := _get_config_value("boss_warning_lead_time", boss_warning_lead_time) as float
	eff_boss_warning_lead_time = clampf(eff_boss_warning_lead_time, 0.0, eff_stage_duration)

	var eff_boss_spawn_distance := _get_config_value("boss_spawn_distance", boss_spawn_distance) as float
	eff_boss_spawn_distance = maxf(eff_boss_spawn_distance, MIN_SPAWN_DISTANCE)

	var eff_boss_max_hp := _get_config_value("boss_max_hp", boss_max_hp) as float
	eff_boss_max_hp = maxf(eff_boss_max_hp, 1.0)

	var eff_boss_damage := _get_config_value("boss_damage", boss_damage) as float
	eff_boss_damage = maxf(eff_boss_damage, 0.0)

	var eff_boss_scale := _get_config_value("boss_scale", boss_scale) as float
	eff_boss_scale = maxf(eff_boss_scale, 0.1)

	var eff_demon_seal_spawn_time := _get_config_value("demon_seal_spawn_time", demon_seal_spawn_time) as float
	eff_demon_seal_spawn_time = clampf(eff_demon_seal_spawn_time, 0.0, eff_stage_duration)

	var eff_demon_seal_min_spawn_distance := _get_config_value("demon_seal_min_spawn_distance", demon_seal_min_spawn_distance) as float
	eff_demon_seal_min_spawn_distance = maxf(eff_demon_seal_min_spawn_distance, MIN_SPAWN_DISTANCE)

	var eff_demon_seal_max_spawn_distance := _get_config_value("demon_seal_max_spawn_distance", demon_seal_max_spawn_distance) as float
	eff_demon_seal_max_spawn_distance = maxf(eff_demon_seal_max_spawn_distance, eff_demon_seal_min_spawn_distance)

	var eff_demon_seal_required_seconds := _get_config_value("demon_seal_required_seconds", demon_seal_required_seconds) as float
	eff_demon_seal_required_seconds = maxf(eff_demon_seal_required_seconds, 0.1)

	var eff_demon_seal_pressure_interval_multiplier := _get_config_value("demon_seal_pressure_interval_multiplier", demon_seal_pressure_interval_multiplier) as float
	eff_demon_seal_pressure_interval_multiplier = clampf(eff_demon_seal_pressure_interval_multiplier, 0.1, 1.0)

	var eff_demon_seal_pressure_max_enemy_bonus := _get_config_value("demon_seal_pressure_max_enemy_bonus", demon_seal_pressure_max_enemy_bonus) as int
	eff_demon_seal_pressure_max_enemy_bonus = maxi(eff_demon_seal_pressure_max_enemy_bonus, 0)

	var eff_demon_seal_reward_orb_count := _get_config_value("demon_seal_reward_orb_count", demon_seal_reward_orb_count) as int
	eff_demon_seal_reward_orb_count = maxi(eff_demon_seal_reward_orb_count, 0)

	var eff_demon_seal_reward_xp_value := _get_config_value("demon_seal_reward_xp_value", demon_seal_reward_xp_value) as float
	eff_demon_seal_reward_xp_value = maxf(eff_demon_seal_reward_xp_value, 0.0)

	var eff_demon_seal_reward_radius := _get_config_value("demon_seal_reward_radius", demon_seal_reward_radius) as float
	eff_demon_seal_reward_radius = maxf(eff_demon_seal_reward_radius, 0.0)

	var eff_first_elite_spawn_time := _get_config_value("first_elite_spawn_time", first_elite_spawn_time) as float
	eff_first_elite_spawn_time = clampf(eff_first_elite_spawn_time, 0.0, eff_stage_duration)

	var eff_second_elite_spawn_time := _get_config_value("second_elite_spawn_time", second_elite_spawn_time) as float
	eff_second_elite_spawn_time = clampf(eff_second_elite_spawn_time, 0.0, eff_stage_duration)

	var eff_elite_spawn_distance := _get_config_value("elite_spawn_distance", elite_spawn_distance) as float
	eff_elite_spawn_distance = maxf(eff_elite_spawn_distance, MIN_SPAWN_DISTANCE)

	var eff_boss_move_speed := _get_config_value("boss_move_speed", boss_move_speed) as float
	eff_boss_move_speed = maxf(eff_boss_move_speed, 0.0)

	var eff_boss_phase_spawn_interval := _get_config_value("boss_phase_spawn_interval", boss_phase_spawn_interval) as float
	eff_boss_phase_spawn_interval = maxf(eff_boss_phase_spawn_interval, 0.1)

	var eff_boss_phase_max_enemies := _get_config_value("boss_phase_max_enemies", boss_phase_max_enemies) as int
	eff_boss_phase_max_enemies = maxi(eff_boss_phase_max_enemies, 0)

	stage_duration = eff_stage_duration
	boss_warning_lead_time = eff_boss_warning_lead_time
	boss_spawn_distance = eff_boss_spawn_distance
	boss_move_speed = eff_boss_move_speed
	boss_max_hp = eff_boss_max_hp
	boss_damage = eff_boss_damage
	boss_scale = eff_boss_scale
	boss_phase_spawn_interval = eff_boss_phase_spawn_interval
	boss_phase_max_enemies = eff_boss_phase_max_enemies
	demon_seal_spawn_time = eff_demon_seal_spawn_time
	demon_seal_min_spawn_distance = eff_demon_seal_min_spawn_distance
	demon_seal_max_spawn_distance = eff_demon_seal_max_spawn_distance
	demon_seal_required_seconds = eff_demon_seal_required_seconds
	demon_seal_pressure_interval_multiplier = eff_demon_seal_pressure_interval_multiplier
	demon_seal_pressure_max_enemy_bonus = eff_demon_seal_pressure_max_enemy_bonus
	demon_seal_reward_orb_count = eff_demon_seal_reward_orb_count
	demon_seal_reward_xp_value = eff_demon_seal_reward_xp_value
	demon_seal_reward_radius = eff_demon_seal_reward_radius
	first_elite_spawn_time = eff_first_elite_spawn_time
	second_elite_spawn_time = eff_second_elite_spawn_time
	elite_spawn_distance = eff_elite_spawn_distance

	# v0.5 补点：应用关卡主题色（L002 设计稿 §5.3）
	# stage_config 未设置或缺少 background_color 时保持当前色（v0.2 兼容）
	if stage_config != null and "background_color" in stage_config:
		RenderingServer.set_default_clear_color(stage_config.background_color)
