class_name HellGuard
extends Enemy

## 冥神甲（L008 E704，肉盾 + 周期护盾）
##
## 行为：
## - 持续追击玩家
## - 每 shield_cooldown 秒激活护盾持续 shield_duration 秒
## - 护盾激活期间免疫所有伤害
## - 视觉：护盾期间在 Body 上方显示半透明蓝圆
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L008

@export var shield_cooldown: float = 8.0
@export var shield_duration: float = 2.0
@export var shield_color: Color = Color(0.3, 0.6, 0.9, 0.35)

var _shield_cooldown_timer: float = 4.0   # 初始错开，避免开场即护盾
var _shield_active_timer: float = 0.0
var _is_shielded: bool = false
var _shield_visual: Polygon2D = null


func _ready() -> void:
	super._ready()
	_create_shield_visual()


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_shield(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = (_player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	_try_damage_player()


func _process_shield(delta: float) -> void:
	if _is_shielded:
		_shield_active_timer -= delta
		if _shield_active_timer <= 0.0:
			_deactivate_shield()
	else:
		_shield_cooldown_timer -= delta
		if _shield_cooldown_timer <= 0.0:
			_activate_shield()


func _activate_shield() -> void:
	_is_shielded = true
	_shield_active_timer = shield_duration
	if is_instance_valid(_shield_visual):
		_shield_visual.visible = true


func _deactivate_shield() -> void:
	_is_shielded = false
	_shield_cooldown_timer = shield_cooldown
	if is_instance_valid(_shield_visual):
		_shield_visual.visible = false


func take_damage(amount: float) -> void:
	if _is_shielded:
		return
	super.take_damage(amount)


func _create_shield_visual() -> void:
	_shield_visual = Polygon2D.new()
	_shield_visual.color = shield_color
	var points := PackedVector2Array()
	var segments: int = 28
	var radius: float = 22.0
	for i in range(segments):
		var ang: float = TAU * float(i) / float(segments)
		points.append(Vector2.RIGHT.rotated(ang) * radius)
	_shield_visual.polygon = points
	_shield_visual.visible = false
	add_child(_shield_visual)
