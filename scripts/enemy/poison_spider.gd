class_name PoisonSpider
extends Enemy

## 毒蛛（L006 E501，接触玩家施加 SLOW 0.8s）
##
## 行为：
## - 持续追击玩家（使用基类 _physics_process）
## - 每次接触命中玩家时，施加 SLOW 地形效果 0.8s，之后用 Timer 移除
##
## 设计参考 docs/L004_L010_TEN_STAGES_DESIGN.md §3 L006

@export var slow_duration: float = 0.8

var _slow_active: bool = false
var _slow_remove_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if _is_dead:
		_cleanup_slow()
		velocity = Vector2.ZERO
		return

	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	_process_slow_timer(delta)

	if not is_instance_valid(_player):
		_find_player()

	if _player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = (_player.global_position - global_position).normalized() * move_speed
	move_and_slide()
	_try_damage_player_with_slow()


func _try_damage_player_with_slow() -> void:
	if _damage_cooldown > 0.0 or damage <= 0.0:
		return

	for target in _damage_targets:
		if _is_player_damage_target(target):
			target.call("take_damage", damage)
			_damage_cooldown = maxf(damage_interval, MIN_DAMAGE_INTERVAL)
			_apply_slow_to_player(target)
			return


func _apply_slow_to_player(target: Object) -> void:
	if not is_instance_valid(target):
		return
	if not target.has_method("apply_terrain_effect"):
		return
	target.call("apply_terrain_effect", TerrainEffect.Type.SLOW, slow_duration)
	_slow_active = true
	_slow_remove_timer = slow_duration


func _process_slow_timer(delta: float) -> void:
	if not _slow_active:
		return
	_slow_remove_timer -= delta
	if _slow_remove_timer <= 0.0:
		_slow_active = false
		if is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
			_player.call("remove_terrain_effect", TerrainEffect.Type.SLOW)


func _cleanup_slow() -> void:
	if _slow_active and is_instance_valid(_player) and _player.has_method("remove_terrain_effect"):
		_player.call("remove_terrain_effect", TerrainEffect.Type.SLOW)
	_slow_active = false
