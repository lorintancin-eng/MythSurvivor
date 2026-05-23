class_name CharacterSelectPanel
extends CanvasLayer

## 角色选择面板（v0.3）
##
## 主菜单启动时弹出，让玩家选择角色（孙悟空 / 修行者）。
## 选择后实例化对应角色场景，强制 name = "Player" 后 add_child 到 Main，
## 调用 HUD._connect_player() 重新绑定 HUD，最后 queue_free 自身。

@export var cultivator_scene: PackedScene


func _on_sun_wukong_button_pressed() -> void:
	# v0.3 孙悟空已删除，等待 v0.4 v2 重做
	push_warning("孙悟空 v0.4 重做中，暂不可用")


func _on_cultivator_button_pressed() -> void:
	_select_character(cultivator_scene)


func _select_character(scene: PackedScene) -> void:
	if scene == null:
		push_warning("CharacterSelectPanel: 角色场景未配置")
		return
	var character := scene.instantiate()
	character.name = "Player"
	var main := get_parent()
	if main != null:
		main.add_child(character)
		# 更新 HUD 的 _player 引用后重新连接信号
		var hud := main.get_node_or_null("HUD")
		if hud != null:
			hud.set("_player", character)
			if hud.has_method("_connect_player"):
				hud.call("_connect_player")
			if hud.has_method("_refresh_initial_state"):
				hud.call("_refresh_initial_state")
			if hud.has_method("_setup_energy_bar"):
				hud.call("_setup_energy_bar")
		# 重绑 StageDirector（修复 Bug 1+5）
		var stage_director := main.get_node_or_null("StageDirector")
		if stage_director != null:
			stage_director.set("_player", character)
			if character.has_signal("died") and stage_director.has_method("_on_player_died"):
				if not character.died.is_connected(stage_director._on_player_died):
					character.died.connect(stage_director._on_player_died)
	queue_free()
