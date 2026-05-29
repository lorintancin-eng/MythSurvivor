class_name XiaoTianQuanWeapon
extends WeaponBase

## 哮天犬召唤控制器 W302（杨戬技能）
##
## 常驻召唤物控制器——不做周期攻击，在 _ready/level_up 时召唤/更新哮天犬。
##
## Lv1: 召唤 1 只（damage 10, slow 30%, no stun）
## Lv2: 咬击 +6 (16), 减速 40%（slow_mult 0.6），stun 0.3s
## Lv3: 召唤第 2 只（2 只并存）
## Lv4: 哮天犬死亡时爆裂 AOE（burst_damage 20, radius 60）
##      TODO: 3s 后自动复活

const XIAO_TIAN_QUAN_UNIT_SCRIPT := preload("res://scripts/weapon/yangjian/xiao_tian_quan_unit.gd")

@export var level: int = 1: set = _apply_level

# 等级派生参数
var _unit_count: int = 1
var _unit_damage: float = 10.0
var _unit_slow_mult: float = 0.7
var _unit_slow_duration: float = 1.0
var _unit_stun_duration: float = 0.0
var _unit_burst_on_death: bool = false

# 管理现有哮天犬实例
var _units: Array[XiaoTianQuanUnit] = []


func _ready() -> void:
	# 哮天犬是常驻召唤物，不参与 WeaponBase 的冷却攻击循环
	# 将冷却设为极大值，屏蔽父类 _try_attack 触发
	cooldown = 9999.0
	_apply_level(level)


## WeaponBase._process 触发此方法，但哮天犬是常驻召唤物，此处 override 为空操作
func _try_attack() -> bool:
	return false


func _apply_level(lv: int) -> void:
	level = clampi(lv, 1, 4)
	match level:
		1:
			_unit_count = 1
			_unit_damage = 10.0
			_unit_slow_mult = 0.7
			_unit_slow_duration = 1.0
			_unit_stun_duration = 0.0
			_unit_burst_on_death = false
		2:
			_unit_count = 1
			_unit_damage = 16.0
			_unit_slow_mult = 0.6
			_unit_slow_duration = 1.0
			_unit_stun_duration = 0.3
			_unit_burst_on_death = false
		3:
			_unit_count = 2
			_unit_damage = 16.0
			_unit_slow_mult = 0.6
			_unit_slow_duration = 1.0
			_unit_stun_duration = 0.3
			_unit_burst_on_death = false
		4:
			_unit_count = 2
			_unit_damage = 16.0
			_unit_slow_mult = 0.6
			_unit_slow_duration = 1.0
			_unit_stun_duration = 0.3
			_unit_burst_on_death = true
	# 升级时同步现有单位属性或调整数量
	_sync_units()


## 同步当前单位数量和属性
func _sync_units() -> void:
	# 清理已失效的引用
	var valid_units: Array[XiaoTianQuanUnit] = []
	for unit in _units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			valid_units.append(unit)
	_units = valid_units

	# 更新现有单位属性
	for unit in _units:
		_configure_unit(unit)

	# 不足时补充召唤
	var needed := _unit_count - _units.size()
	for i in range(needed):
		_spawn_unit()

	# 超出时（升级降级场景，实际不发生）移除多余
	while _units.size() > _unit_count:
		var surplus := _units.pop_back()
		if is_instance_valid(surplus):
			surplus.queue_free()


## 召唤一只哮天犬并加入场景
func _spawn_unit() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		push_warning("XiaoTianQuanWeapon: current_scene is null, cannot spawn unit.")
		return
	var unit: XiaoTianQuanUnit = XIAO_TIAN_QUAN_UNIT_SCRIPT.new()
	_configure_unit(unit)
	unit._controller = self
	# 位置偏移：紧贴玩家周围
	var offset_angle := TAU * float(_units.size()) / float(maxi(_unit_count, 1))
	var spawn_offset := Vector2.RIGHT.rotated(offset_angle) * 36.0
	if owner != null and owner is Node2D:
		unit.global_position = (owner as Node2D).global_position + spawn_offset
	else:
		unit.global_position = global_position + spawn_offset
	scene.add_child(unit)
	_units.append(unit)


## 将等级参数写入单位
func _configure_unit(unit: XiaoTianQuanUnit) -> void:
	unit.damage = _unit_damage
	unit.slow_multiplier = _unit_slow_mult
	unit.slow_duration = _unit_slow_duration
	unit.stun_duration = _unit_stun_duration
	unit.burst_on_death = _unit_burst_on_death


## 释放时销毁所有哮天犬
func _exit_tree() -> void:
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
