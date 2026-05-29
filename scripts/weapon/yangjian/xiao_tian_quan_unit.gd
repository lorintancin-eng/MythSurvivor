class_name XiaoTianQuanUnit
extends Node2D

## 哮天犬个体 AI（杨戬 W302 召唤物）
##
## 常驻召唤物（无寿命限制），自动追击最近敌人并咬击。
## 咬击附带减速（duck typing，不改 enemy.gd）。
## Lv2+: stun 0.3s（短暂 move_speed=0）
## Lv4: 死亡爆裂 AOE + 3s 后复活（MVP：爆裂实现，复活 TODO）
##
## 参考 HairCloneUnit 的 AI 循环模式

@export var damage: float = 10.0
@export var attack_interval: float = 1.2
@export var attack_range: float = 28.0
@export var move_speed: float = 160.0
@export var slow_multiplier: float = 0.7
@export var slow_duration: float = 1.0
@export var stun_duration: float = 0.0   # Lv2+ 设为 0.3
@export var burst_on_death: bool = false  # Lv4
@export var burst_damage: float = 20.0
@export var burst_radius: float = 60.0
@export var respawn_time: float = 3.0    # Lv4 复活时间（TODO）

# 控制器引用（复活时通知父控制器）
var _controller: Node = null

var _attack_cooldown: float = 0.0
var _is_dying: bool = false


func _ready() -> void:
	_build_visual()


## 视觉：青白色小菱形代表哮天犬
func _build_visual() -> void:
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -9),
		Vector2(7, 0),
		Vector2(0, 9),
		Vector2(-7, 0),
	])
	visual.color = Color(0.6, 0.85, 1.0, 0.9)
	add_child(visual)


func _process(delta: float) -> void:
	if _is_dying:
		return
	# 攻击冷却推进
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	# 找最近敌人
	var target := _find_nearest_enemy()
	if target == null:
		return
	# 移动或攻击
	var dist := global_position.distance_to(target.global_position)
	if dist > attack_range:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		global_position += dir * move_speed * delta
	else:
		if _attack_cooldown <= 0.0:
			_attack(target)
			_attack_cooldown = attack_interval


func _attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	# 伤害（duck typing）
	if target.has_method("take_damage"):
		target.take_damage(damage)
	# 减速（duck typing：enemy.move_speed 字段）
	_apply_slow(target)


## 减速：直接修改 move_speed 字段，Timer 后恢复（duck typing）
func _apply_slow(target: Node2D) -> void:
	if not "move_speed" in target:
		return
	var original_speed: float = target.move_speed
	# stun：move_speed 置 0；否则按倍率减速
	if stun_duration > 0.0:
		target.move_speed = 0.0
		var stun_timer := get_tree().create_timer(stun_duration)
		stun_timer.timeout.connect(func():
			if is_instance_valid(target):
				target.move_speed = original_speed
		)
	else:
		target.move_speed = original_speed * slow_multiplier
		var slow_timer := get_tree().create_timer(slow_duration)
		slow_timer.timeout.connect(func():
			if is_instance_valid(target):
				target.move_speed = original_speed
		)


## 找最近敌人（全局搜索 "enemies" group）
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var dist_sq: float = global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy_node
	return nearest


## 死亡（Lv4 爆裂 + 可选复活）
func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	# Lv4 爆裂 AOE
	if burst_on_death:
		_do_burst()
	# 视觉淡出
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_on_death_complete)


func _on_death_complete() -> void:
	# TODO(Lv4 复活)：通知控制器 respawn_time 后重新召唤此犬
	# if burst_on_death and _controller != null and _controller.has_method("respawn_unit"):
	#     get_tree().create_timer(respawn_time).timeout.connect(
	#         func(): if is_instance_valid(_controller): _controller.respawn_unit()
	#     )
	queue_free()


func _do_burst() -> void:
	var burst_sq := burst_radius * burst_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if global_position.distance_squared_to(enemy_node.global_position) > burst_sq:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(burst_damage)
