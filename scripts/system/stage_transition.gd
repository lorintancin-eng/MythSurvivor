class_name StageTransition
extends CanvasLayer

## 关卡过渡 UI + 协调器（F01）
## 触发流程：
## T=0.0s  Boss 死亡 → StageDirector emit boss_died
## T=1.5s  start_transition(next_stage_id) 调用
##         - 黑屏 alpha 0→1 (0.8s)
## T=2.3s  全屏黑 + 显示 next stage name 2s
## T=4.3s  emit transition_midpoint signal（StageDirector 接收 → 清场 + load_config + 重置 elapsed）
## T=5.3s  黑屏 alpha 1→0 (0.8s)
## T=6.1s  emit transition_completed signal

signal transition_midpoint(next_stage_id: String)
signal transition_completed(next_stage_id: String)

const FADE_IN_DURATION: float = 0.8
const HOLD_DURATION: float = 2.0
const FADE_OUT_DURATION: float = 0.8

@export var layer_order: int = 100

@onready var _black_screen: ColorRect = $BlackScreen
@onready var _stage_name_label: Label = $BlackScreen/CenterLabel

var _current_next_stage_id: String = ""
var _is_transitioning: bool = false


func _ready() -> void:
	layer = layer_order
	_black_screen.color = Color(0.0, 0.0, 0.0, 0.0)
	_black_screen.visible = false
	_stage_name_label.text = ""
	_stage_name_label.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


## 启动过渡。next_stage_id 用于查询 stage_name + emit signal。
func start_transition(next_stage_id: String) -> void:
	if _is_transitioning:
		push_warning("StageTransition: already transitioning")
		return
	_is_transitioning = true
	_current_next_stage_id = next_stage_id

	var stage_name := next_stage_id
	var stage_config := StageRegistry.get_stage(next_stage_id)
	if stage_config != null and stage_config.stage_name != "":
		stage_name = stage_config.stage_name
	_stage_name_label.text = stage_name

	_black_screen.visible = true
	_black_screen.color = Color(0.0, 0.0, 0.0, 0.0)

	var tween := create_tween()
	tween.tween_property(_black_screen, "color", Color(0.0, 0.0, 0.0, 1.0), FADE_IN_DURATION)
	tween.tween_callback(_show_stage_name)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_callback(_on_midpoint)
	tween.tween_property(_black_screen, "color", Color(0.0, 0.0, 0.0, 0.0), FADE_OUT_DURATION)
	tween.tween_callback(_on_finish)


func _show_stage_name() -> void:
	_stage_name_label.visible = true


func _on_midpoint() -> void:
	transition_midpoint.emit(_current_next_stage_id)
	_stage_name_label.visible = false


func _on_finish() -> void:
	_black_screen.visible = false
	_is_transitioning = false
	transition_completed.emit(_current_next_stage_id)
	_current_next_stage_id = ""
