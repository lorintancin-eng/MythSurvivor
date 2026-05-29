class_name QianKunProjectile
extends Area2D

## 乾坤圈回旋镖投射物 W203
##
## 阶段 1：飞向目标（到达或超时后进入阶段 2）
## 阶段 2：折返回 owner（Player）当前位置，途中实时追踪
## 两段各造成一次伤害，每段去重（同一敌人每段只受一次伤害）

enum Phase { TO_TARGET, RETURN }

const SPEED: float = 320.0
const MAX_TRAVEL_TIME: float = 1.2   # 防止永远飞不到目标
const REACH_THRESHOLD: float = 24.0  # 到达距离阈值（像素）
const AOE_RADIUS: float = 40.0       # Lv2+ 折返段 AOE 半径

var _damage: float = 15.0
var _aoe_on_return: bool = false      # Lv2+ 折返时额外 AOE
var _player_ref: Node2D = null        # 折返目标（Player 节点）
var _phase: Phase = Phase.TO_TARGET
var _target_pos: Vector2 = Vector2.ZERO  # 阶段 1 飞行目标（世界坐标，快照）
var _travel_time: float = 0.0
var _hit_phase1: Array = []
var _hit_phase2: Array = []

# 视觉
var _visual: Polygon2D


func _ready() -> void:
	_build_visual()
	# 连接 Area2D 进入信号（基础碰撞检测用，也可仅用 _process 距离检测）
	area_entered.connect(_on_area_entered)


func launch(
	target_position: Vector2,
	damage: float,
	player_node: Node2D,
	aoe_on_return: bool
) -> void:
	_target_pos = target_position
	_damage = maxf(damage, 0.0)
	_player_ref = player_node
	_aoe_on_return = aoe_on_return
	_phase = Phase.TO_TARGET
	_travel_time = 0.0
	_hit_phase1.clear()
	_hit_phase2.clear()


func _process(delta: float) -> void:
	_travel_time += delta

	match _phase:
		Phase.TO_TARGET:
			_process_to_target(delta)
		Phase.RETURN:
			_process_return(delta)


func _process_to_target(delta: float) -> void:
	var direction := global_position.direction_to(_target_pos)
	global_position += direction * SPEED * delta

	# 检测途中命中
	_check_hit_enemies(_hit_phase1)

	# 到达目标或超时 → 转入折返
	var dist := global_position.distance_to(_target_pos)
	if dist <= REACH_THRESHOLD or _travel_time >= MAX_TRAVEL_TIME:
		_enter_return_phase()


func _enter_return_phase() -> void:
	_phase = Phase.RETURN
	_travel_time = 0.0

	# Lv2+ AOE：在当前位置做一次圆形 AOE
	if _aoe_on_return:
		_apply_aoe_at(global_position)


func _process_return(delta: float) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		queue_free()
		return

	var return_target := _player_ref.global_position
	var direction := global_position.direction_to(return_target)
	global_position += direction * SPEED * delta

	# 检测途中命中（折返段去重）
	_check_hit_enemies(_hit_phase2)

	# 返回到玩家附近 → 消失
	if global_position.distance_to(return_target) <= REACH_THRESHOLD:
		queue_free()

	# 超时保险
	if _travel_time >= MAX_TRAVEL_TIME * 2.0:
		queue_free()


## 检测并伤害范围内敌人（hit_set 去重）
func _check_hit_enemies(hit_set: Array) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if enemy_node in hit_set:
			continue
		var dist := global_position.distance_to(enemy_node.global_position)
		if dist <= 18.0:  # 投射物命中半径
			hit_set.append(enemy_node)
			enemy_node.call("take_damage", _damage)


## Lv2+ 折返时圆形 AOE
func _apply_aoe_at(pos: Vector2) -> void:
	var aoe_damage := _damage * 0.6  # AOE 伤害略低于主体
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.is_queued_for_deletion():
			continue
		if pos.distance_to(enemy_node.global_position) <= AOE_RADIUS:
			enemy_node.call("take_damage", aoe_damage)


func _on_area_entered(_area: Area2D) -> void:
	pass  # 用 _process 距离检测，此信号预留


## 简单视觉：橙色小圆圈代表乾坤圈
func _build_visual() -> void:
	_visual = Polygon2D.new()
	_visual.color = Color(1.0, 0.65, 0.1, 0.9)
	var pts := PackedVector2Array()
	var seg := 12
	var r := 8.0
	for i in range(seg):
		var angle := float(i) / float(seg) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	_visual.polygon = pts
	add_child(_visual)
