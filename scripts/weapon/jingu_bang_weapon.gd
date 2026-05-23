class_name JinguBangWeapon
extends WeaponBase

## 如意金箍棒（孙悟空初始武器 W101）
##
## 类型：近身旋转（持续生效，无主动冷却）
## 攻击模式：金箍棒在玩家周围持续顺时针旋转，接触敌人造成伤害
## 范围：旋转半径 90 px
## 防多重命中：同一敌人 0.5s 内不重复受伤
##
## 详细设计：docs/04_SKILL_DESIGN.md §5.2 W101
## 暂不挂载到任何场景，T209 角色选择 UI 完成后由 SunWukong.tscn 接入

@export var radius: float = 90.0
@export var rotation_speed: float = TAU  # 360°/s = TAU rad/s
@export var stick_length: float = 50.0
@export var stick_width: float = 6.0
@export var rehit_cooldown: float = 0.5
@export var character_owner: String = "sun_wukong"
@export var element: String = "metal"  # 五行金，v0.5 启用

# 当前棒的角度（弧度）
var _current_angle: float = 0.0

# 防多重命中字典 {Enemy实例: 剩余冷却时间 float}
var _hit_cooldowns: Dictionary = {}

var _visual: Line2D = null


func _ready() -> void:
	if damage <= 0.0:
		damage = 10.0
	_ensure_visual()
	_update_visual()


# 持续生效，完全 override 不调用 super._process
func _process(delta: float) -> void:
	_current_angle = fposmod(_current_angle + rotation_speed * delta, TAU)
	_update_visual()
	_tick_cooldowns(delta)
	_check_hits()


func _ensure_visual() -> void:
	if has_node("Visual"):
		_visual = $Visual
		return
	_visual = Line2D.new()
	_visual.name = "Visual"
	_visual.width = stick_width
	_visual.default_color = Color(0.95, 0.85, 0.45)  # 金色
	add_child(_visual)


func _update_visual() -> void:
	if _visual == null:
		return
	# 棒从内圈 (radius - stick_length/2) 延伸到外圈 (radius + stick_length/2)
	var dir := Vector2.RIGHT.rotated(_current_angle)
	var inner := dir * (radius - stick_length * 0.5)
	var outer := dir * (radius + stick_length * 0.5)
	_visual.points = PackedVector2Array([inner, outer])


func _tick_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for enemy in _hit_cooldowns.keys():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			to_remove.append(enemy)
			continue
		_hit_cooldowns[enemy] -= delta
		if _hit_cooldowns[enemy] <= 0.0:
			to_remove.append(enemy)
	for key in to_remove:
		_hit_cooldowns.erase(key)


func _check_hits() -> void:
	# 棒的命中点位于半径 radius 处
	var hit_center: Vector2 = global_position + Vector2.RIGHT.rotated(_current_angle) * radius
	# 命中范围：以 hit_center 为中心，半径约 stick_length/2 + 一点宽度容差
	var hit_radius: float = stick_length * 0.5 + stick_width
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if _hit_cooldowns.has(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.global_position.distance_to(hit_center) > hit_radius:
			continue
		# 命中
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", _get_damage())
		_hit_cooldowns[enemy] = rehit_cooldown
