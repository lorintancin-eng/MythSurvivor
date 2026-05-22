class_name HUD
extends CanvasLayer

@export var player_path: NodePath = ^"../Player"
@export var enemy_spawner_path: NodePath = ^"../EnemySpawner"
@export var game_over_panel_path: NodePath = ^"../GameOverPanel"
@export var stage_director_path: NodePath = ^"../StageDirector"

const _STATUS_PRIORITY_NONE := 0
const _STATUS_PRIORITY_DEMON_SEAL := 10
const _STATUS_PRIORITY_BOSS_WARNING := 20
const _STATUS_PRIORITY_BOSS_SPAWNED := 30
const _STATUS_PRIORITY_RUN_FINISHED := 40

var _survival_time: float = 0.0
var _stage_duration: float = 0.0
var _displayed_time_seconds: int = -1
var _kill_count: int = 0
var _final_level: int = 1
var _is_run_finished: bool = false
var _stage_status_priority: int = _STATUS_PRIORITY_NONE

var _player: Player
var _enemy_spawner: EnemySpawner
var _game_over_panel: GameOverPanel
var _stage_director: Node

@onready var _health_label: Label = $Panel/Margin/Content/HealthLabel
@onready var _level_label: Label = $Panel/Margin/Content/LevelLabel
@onready var _experience_label: Label = $Panel/Margin/Content/ExperienceLabel
@onready var _time_label: Label = $Panel/Margin/Content/TimeLabel
@onready var _kill_label: Label = $Panel/Margin/Content/KillLabel
@onready var _stage_status_label: Label = $Panel/Margin/Content/StageStatusLabel


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_enemy_spawner = get_node_or_null(enemy_spawner_path) as EnemySpawner
	_game_over_panel = get_node_or_null(game_over_panel_path) as GameOverPanel
	_stage_director = get_node_or_null(stage_director_path)

	_connect_player()
	_connect_enemy_spawner()
	_connect_stage_director()
	_refresh_initial_state()
	_update_time_label(true)
	_update_kill_label()
	_set_stage_status("")


func _process(delta: float) -> void:
	if _is_run_finished or _stage_director != null:
		return

	_survival_time += delta
	_update_time_label()


func _connect_player() -> void:
	if _player == null:
		push_warning("HUD could not find Player at %s." % player_path)
		return

	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if not _player.experience_changed.is_connected(_on_player_experience_changed):
		_player.experience_changed.connect(_on_player_experience_changed)
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)


func _connect_enemy_spawner() -> void:
	if _enemy_spawner == null:
		push_warning("HUD could not find EnemySpawner at %s." % enemy_spawner_path)
		return

	_kill_count = _enemy_spawner.defeated_enemy_count
	if not _enemy_spawner.enemy_defeated.is_connected(_on_enemy_defeated):
		_enemy_spawner.enemy_defeated.connect(_on_enemy_defeated)


func _connect_stage_director() -> void:
	if _stage_director == null:
		return

	if not _stage_director.is_connected(&"stage_time_changed", _on_stage_time_changed):
		_stage_director.connect(&"stage_time_changed", _on_stage_time_changed)
	if not _stage_director.is_connected(&"boss_warning_started", _on_boss_warning_started):
		_stage_director.connect(&"boss_warning_started", _on_boss_warning_started)
	if not _stage_director.is_connected(&"boss_spawned", _on_boss_spawned):
		_stage_director.connect(&"boss_spawned", _on_boss_spawned)
	if not _stage_director.is_connected(&"demon_seal_spawned", _on_demon_seal_spawned):
		_stage_director.connect(&"demon_seal_spawned", _on_demon_seal_spawned)
	if not _stage_director.is_connected(&"demon_seal_progress_changed", _on_demon_seal_progress_changed):
		_stage_director.connect(&"demon_seal_progress_changed", _on_demon_seal_progress_changed)
	if not _stage_director.is_connected(&"demon_seal_completed", _on_demon_seal_completed):
		_stage_director.connect(&"demon_seal_completed", _on_demon_seal_completed)
	if not _stage_director.is_connected(&"stage_cleared", _on_stage_cleared):
		_stage_director.connect(&"stage_cleared", _on_stage_cleared)


func _refresh_initial_state() -> void:
	if _player == null:
		_update_health_label(0.0, 0.0)
		_update_experience_label(0.0, 0.0, _final_level)
		return

	var progression_state := _player.get_progression_state()
	var current_hp := float(progression_state.get("current_hp", 0.0))
	var max_hp := float(progression_state.get("max_hp", 0.0))
	var current_xp := float(progression_state.get("current_xp", 0.0))
	var xp_to_next_level := float(progression_state.get("xp_to_next_level", 0.0))
	var level := int(progression_state.get("level", 1))
	_update_health_label(current_hp, max_hp)
	_update_experience_label(current_xp, xp_to_next_level, level)


func _update_health_label(current_hp: float, max_hp: float) -> void:
	_health_label.text = "气血 %s / %s" % [_format_number(current_hp), _format_number(max_hp)]


func _update_experience_label(current_xp: float, xp_to_next_level: float, level: int) -> void:
	_final_level = maxi(level, 1)
	_level_label.text = "境界 %d" % _final_level
	_experience_label.text = "修为 %s / %s" % [_format_number(current_xp), _format_number(xp_to_next_level)]


func _update_time_label(force: bool = false) -> void:
	var time_seconds := floori(_survival_time)
	if not force and time_seconds == _displayed_time_seconds:
		return

	_displayed_time_seconds = time_seconds
	if _stage_duration > 0.0:
		_time_label.text = "历劫时间 %s / %s" % [_format_time(_survival_time), _format_time(_stage_duration)]
	else:
		_time_label.text = "历劫时间 %s" % _format_time(_survival_time)


func _update_kill_label() -> void:
	_kill_label.text = "镇妖数 %d" % _kill_count


func _set_stage_status(status_text: String, priority: int = _STATUS_PRIORITY_DEMON_SEAL) -> void:
	if status_text.is_empty():
		_stage_status_priority = _STATUS_PRIORITY_NONE
		_stage_status_label.text = ""
		_stage_status_label.visible = false
		return

	if priority < _stage_status_priority:
		return

	_stage_status_priority = priority
	_stage_status_label.text = status_text
	_stage_status_label.visible = true


func _format_time(total_seconds: float) -> String:
	var whole_seconds := floori(maxf(total_seconds, 0.0))
	var minutes := int(whole_seconds / 60)
	var seconds := whole_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _format_number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))

	return "%.1f" % value


func _on_player_health_changed(current_hp: float, max_hp: float) -> void:
	_update_health_label(current_hp, max_hp)


func _on_player_experience_changed(current_xp: float, xp_to_next_level: float, level: int) -> void:
	_update_experience_label(current_xp, xp_to_next_level, level)


func _on_enemy_defeated(defeated_count: int) -> void:
	_kill_count = maxi(defeated_count, 0)
	_update_kill_label()


func _on_stage_time_changed(elapsed_time: float, stage_duration: float) -> void:
	_survival_time = elapsed_time
	_stage_duration = stage_duration
	_update_time_label()


func _on_boss_warning_started(_warning_lead_time: float) -> void:
	_set_stage_status("妖气暴涨，妖王即将降临", _STATUS_PRIORITY_BOSS_WARNING)


func _on_boss_spawned(_boss: Enemy) -> void:
	_set_stage_status("妖王降临", _STATUS_PRIORITY_BOSS_SPAWNED)


func _on_demon_seal_spawned(_demon_seal: Area2D) -> void:
	_set_stage_status("镇妖碑已现身", _STATUS_PRIORITY_DEMON_SEAL)


func _on_demon_seal_progress_changed(progress_seconds: float, required_seconds: float, is_sealing: bool) -> void:
	var progress_percent := 0
	if required_seconds > 0.0:
		progress_percent = roundi(clampf(progress_seconds / required_seconds, 0.0, 1.0) * 100.0)

	var suffix := ""
	if not is_sealing:
		suffix = "（暂停）"
	_set_stage_status("镇妖碑封印 %d%%%s" % [progress_percent, suffix], _STATUS_PRIORITY_DEMON_SEAL)


func _on_demon_seal_completed(_demon_seal: Area2D) -> void:
	_set_stage_status("镇妖碑封印完成", _STATUS_PRIORITY_DEMON_SEAL)


func _on_stage_cleared(stage_time: float) -> void:
	if _is_run_finished:
		return

	_is_run_finished = true
	_survival_time = stage_time
	_update_time_label(true)
	_set_stage_status("封印完成", _STATUS_PRIORITY_RUN_FINISHED)
	if _game_over_panel != null:
		_game_over_panel.show_stage_clear(_survival_time, _kill_count, _final_level)

	get_tree().paused = true


func _on_player_died() -> void:
	if _is_run_finished:
		return

	_is_run_finished = true
	_update_time_label(true)
	_set_stage_status("道消身陨", _STATUS_PRIORITY_RUN_FINISHED)
	if _game_over_panel != null:
		_game_over_panel.show_summary(_survival_time, _kill_count, _final_level)

	get_tree().paused = true
