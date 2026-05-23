class_name HairClone
extends Area2D

## 毫毛分身（孙悟空武器 W103 的投射物个体）
##
## 朝指定方向直线移动，撞敌自爆 70 px 范围。
## 寿命 6s 结束则安静消失（不自爆）。
## hp=1，被攻击立即自爆。
##
## 详细设计：docs/04_SKILL_DESIGN.md §5.2 W103

@export var move_speed: float = 200.0
@export var lifetime: float = 6.0
@export var explosion_radius: float = 70.0
@export var explosion_damage: float = 25.0
## 接触触发半径（与 enemy 距离 <= 此值时引爆）。采用 distance check 与
## 项目其他武器（flying_sword/jingu_bang）保持一致，避免物理 layer 配置坑
@export var contact_radius: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var _has_exploded: bool = false
var _alive_time: float = 0.0

# 小猴 hp=1（被击杀立即触发自爆）
var hp: float = 1.0


func _ready() -> void:
	# 视觉：灰白色小三角剪影
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-6, 6),
		Vector2(6, 6),
		Vector2(0, -8),
	])
	visual.color = Color(0.9, 0.85, 0.85, 0.9)
	add_child(visual)
	# 加入投射物 group
	add_to_group("hair_clones")


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return
	_alive_time += delta
	if _alive_time >= lifetime:
		# 寿命到，淡出消失（与爆炸视觉一致）
		_fade_and_free()
		return
	# 直线移动
	global_position += direction * move_speed * delta
	# 接触检测（与项目其他武器一致用 distance，不依赖物理 layer）
	_check_contact()


func _check_contact() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		# 取敌人 collision_radius（如果有），默认 8
		var enemy_radius: float = 8.0
		if "collision_radius" in enemy_node:
			enemy_radius = enemy_node.collision_radius
		var total_radius: float = contact_radius + enemy_radius
		if global_position.distance_squared_to(enemy_node.global_position) <= total_radius * total_radius:
			_explode()
			return


# 被攻击调用（hp = 1，立即自爆）
func take_damage(amount: float) -> void:
	if _has_exploded:
		return
	hp -= amount
	if hp <= 0.0:
		_explode()


func _explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	# 范围伤害（distance_squared 避免开方，性能更好）
	var explosion_radius_squared := explosion_radius * explosion_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var dist_sq: float = global_position.distance_squared_to(enemy_node.global_position)
		if dist_sq > explosion_radius_squared:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.call("take_damage", explosion_damage)
	# 视觉：淡出消失
	_fade_and_free()


func _fade_and_free() -> void:
	_has_exploded = true  # 防重入（寿命到期与 _explode 同帧时）
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
