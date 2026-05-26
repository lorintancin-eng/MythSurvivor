class_name VictoryPanel
extends CanvasLayer

## 通关结算面板（L003 G13，v0.6）
## 显示太上邀末煌（通关）+ 存活时长 / 击杀数 / 最高境界 / 角色

signal restart_requested

@onready var _time_label: Label = $Overlay/Center/Panel/Margin/Content/TimeLabel
@onready var _kills_label: Label = $Overlay/Center/Panel/Margin/Content/KillsLabel
@onready var _level_label: Label = $Overlay/Center/Panel/Margin/Content/LevelLabel
@onready var _character_label: Label = $Overlay/Center/Panel/Margin/Content/CharacterLabel
@onready var _restart_button: Button = $Overlay/Center/Panel/Margin/Content/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED as ProcessMode
	visible = false
	_restart_button.pressed.connect(_on_restart_pressed)


func show_victory(stats: Dictionary) -> void:
	_time_label.text = "历劫时间 %s" % _format_time(stats.get("elapsed_time", 0.0))
	_kills_label.text = "镇妖数 %d" % maxi(int(stats.get("kills", 0)), 0)
	_level_label.text = "最终境界 %d" % maxi(int(stats.get("level", 1)), 1)
	var char_name: String = String(stats.get("character_name", ""))
	_character_label.text = "道侣：%s" % char_name if char_name != "" else "道侣：无名"
	visible = true
	get_tree().paused = true
	_restart_button.grab_focus()


func _format_time(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	var m := total / 60
	var s := total % 60
	return "%02d:%02d" % [m, s]


func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	restart_requested.emit()
	get_tree().reload_current_scene()
