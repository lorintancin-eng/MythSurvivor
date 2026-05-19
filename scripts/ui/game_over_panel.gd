class_name GameOverPanel
extends CanvasLayer

signal restart_requested

@onready var _time_label: Label = $Overlay/Center/Panel/Margin/Content/TimeLabel
@onready var _kill_label: Label = $Overlay/Center/Panel/Margin/Content/KillLabel
@onready var _level_label: Label = $Overlay/Center/Panel/Margin/Content/LevelLabel
@onready var _restart_button: Button = $Overlay/Center/Panel/Margin/Content/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as ProcessMode
	visible = false
	_restart_button.pressed.connect(_on_restart_button_pressed)


func show_summary(survival_time: float, kill_count: int, final_level: int) -> void:
	_time_label.text = "存活时间 %s" % _format_time(survival_time)
	_kill_label.text = "镇伏数量 %d" % maxi(kill_count, 0)
	_level_label.text = "最终境界 %d" % maxi(final_level, 1)
	visible = true
	_restart_button.grab_focus()


func hide_panel() -> void:
	visible = false


func _format_time(total_seconds: float) -> String:
	var whole_seconds := floori(maxf(total_seconds, 0.0))
	var minutes := int(whole_seconds / 60)
	var seconds := whole_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	restart_requested.emit()
	get_tree().reload_current_scene()
