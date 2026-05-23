class_name Player
extends CharacterBody2D

signal died
signal health_changed(current_hp: float, max_hp: float)
signal experience_changed(current_xp: float, xp_to_next_level: float, level: int)
signal level_reached(level: int)
signal upgrade_applied(upgrade_id: StringName)

const HEALTH_BAR_WIDTH: float = 36.0
const HEALTH_BAR_HEIGHT: float = 5.0
const DEFAULT_LEVEL_UP_PANEL_SCENE: PackedScene = preload("res://scenes/ui/LevelUpPanel.tscn")
const UPGRADE_TALISMAN_DAMAGE := &"talisman_damage"
const UPGRADE_TALISMAN_COOLDOWN := &"talisman_cooldown"
const UPGRADE_TALISMAN_COUNT := &"talisman_count"
const UPGRADE_TALISMAN_SPEED := &"talisman_speed"
const UPGRADE_UNLOCK_FLYING_SWORD := &"unlock_flying_sword"
const UPGRADE_FLYING_SWORD_DAMAGE := &"flying_sword_damage"
const UPGRADE_FLYING_SWORD_COOLDOWN := &"flying_sword_cooldown"
const UPGRADE_FLYING_SWORD_PIERCE := &"flying_sword_pierce"
const UPGRADE_FLYING_SWORD_COUNT := &"flying_sword_count"
const UPGRADE_UNLOCK_THUNDER_LAW := &"unlock_thunder_law"
const UPGRADE_THUNDER_LAW_DAMAGE := &"thunder_law_damage"
const UPGRADE_THUNDER_LAW_COOLDOWN := &"thunder_law_cooldown"
const UPGRADE_THUNDER_LAW_RADIUS := &"thunder_law_radius"
const UPGRADE_THUNDER_LAW_TARGET_COUNT := &"thunder_law_target_count"
const UPGRADE_UNLOCK_BAGUA_ARRAY := &"unlock_bagua_array"
const UPGRADE_BAGUA_ARRAY_DAMAGE := &"bagua_array_damage"
const UPGRADE_BAGUA_ARRAY_RADIUS := &"bagua_array_radius"
const UPGRADE_BAGUA_ARRAY_ROTATION_SPEED := &"bagua_array_rotation_speed"
const UPGRADE_BAGUA_ARRAY_TICK_RATE := &"bagua_array_tick_rate"
const UPGRADE_UNLOCK_EXPLOSIVE_TALISMAN := &"unlock_explosive_talisman"
const UPGRADE_EXPLOSIVE_TALISMAN_RADIUS := &"explosive_talisman_radius"
const UPGRADE_EXPLOSIVE_TALISMAN_DAMAGE := &"explosive_talisman_damage"
const UPGRADE_EXPLOSIVE_TALISMAN_COUNT := &"explosive_talisman_count"
const UPGRADE_EXPLOSIVE_TALISMAN_COOLDOWN := &"explosive_talisman_cooldown"
const UPGRADE_UNLOCK_MOUNTAIN_SEAL := &"unlock_mountain_seal"
const UPGRADE_MOUNTAIN_SEAL_DAMAGE := &"mountain_seal_damage"
const UPGRADE_MOUNTAIN_SEAL_RADIUS := &"mountain_seal_radius"
const UPGRADE_MOUNTAIN_SEAL_COOLDOWN := &"mountain_seal_cooldown"
const UPGRADE_MAX_HP := &"max_hp"
const UPGRADE_MOVE_SPEED := &"move_speed"
const UPGRADE_PICKUP_RADIUS := &"pickup_radius"
const UPGRADE_XP_GAIN := &"xp_gain"

@export var move_speed: float = 180.0
@export var max_hp: float = 100.0
@export var initial_xp_to_next_level: float = 18.0
@export var xp_growth_multiplier: float = 1.28
@export var xp_growth_flat: float = 6.0
@export var upgrade_random_seed: int = 2401
@export var level_up_panel_scene: PackedScene = DEFAULT_LEVEL_UP_PANEL_SCENE
@export var xp_gain_multiplier: float = 1.0
@export var pickup_radius_bonus: float = 0.0

var current_hp: float = 0.0
var current_xp: float = 0.0
var xp_to_next_level: float = 0.0
var level: int = 1

var _is_dead: bool = false
var _pending_upgrade_choices: int = 0
var _is_selecting_upgrade: bool = false
var _was_tree_paused_before_level_up: bool = false
var _is_flying_sword_unlocked: bool = false
var _is_thunder_law_unlocked: bool = false
var _is_bagua_array_unlocked: bool = false
var _is_explosive_talisman_unlocked: bool = false
var _is_mountain_seal_unlocked: bool = false
var _upgrade_rng := RandomNumberGenerator.new()
var _level_up_panel: LevelUpPanel

@onready var _health_fill: Polygon2D = $HealthBar/Fill
@onready var _talisman_weapon: TalismanWeapon = $TalismanWeapon
@onready var _flying_sword_weapon: FlyingSwordWeapon = $FlyingSwordWeapon
@onready var _thunder_law_weapon: ThunderLawWeapon = $ThunderLawWeapon
@onready var _bagua_array_weapon = $BaguaArrayWeapon
@onready var _explosive_talisman_weapon = $ExplosiveTalismanWeapon
@onready var _mountain_seal_weapon = $MountainSealWeapon
@onready var _character_base: CharacterBase = $CharacterBase


func _ready() -> void:
	if _character_base != null:
		max_hp = _character_base.max_health
		move_speed = _character_base.move_speed
	_ensure_input_actions()
	_set_weapon_unlocked(_flying_sword_weapon, _is_flying_sword_unlocked)
	_set_weapon_unlocked(_thunder_law_weapon, _is_thunder_law_unlocked)
	_set_weapon_unlocked(_bagua_array_weapon, _is_bagua_array_unlocked)
	_set_weapon_unlocked(_explosive_talisman_weapon, _is_explosive_talisman_unlocked)
	_set_weapon_unlocked(_mountain_seal_weapon, _is_mountain_seal_unlocked)
	max_hp = maxf(max_hp, 1.0)
	current_hp = max_hp
	level = maxi(level, 1)
	current_xp = maxf(current_xp, 0.0)
	xp_to_next_level = maxf(initial_xp_to_next_level, 1.0)
	_upgrade_rng.seed = upgrade_random_seed
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	experience_changed.emit(current_xp, xp_to_next_level, level)


func _physics_process(_delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * move_speed
	move_and_slide()


func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_hp = maxf(current_hp - amount, 0.0)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_die()


func gain_experience(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	current_xp += amount * maxf(xp_gain_multiplier, 0.0)
	var levels_gained := 0
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = _get_next_xp_threshold(xp_to_next_level)
		levels_gained += 1
		level_reached.emit(level)

	experience_changed.emit(current_xp, xp_to_next_level, level)

	if levels_gained > 0:
		_queue_upgrade_choices(levels_gained)


func get_progression_state() -> Dictionary:
	return {
		"level": level,
		"current_xp": current_xp,
		"xp_to_next_level": xp_to_next_level,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"pickup_radius_bonus": pickup_radius_bonus,
		"xp_gain_multiplier": xp_gain_multiplier,
	}


func get_pickup_radius_bonus() -> float:
	return maxf(pickup_radius_bonus, 0.0)


func _update_health_bar() -> void:
	if _health_fill == null:
		return

	var health_ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	var left := -HEALTH_BAR_WIDTH * 0.5
	var right := left + HEALTH_BAR_WIDTH * health_ratio
	var top := -HEALTH_BAR_HEIGHT * 0.5
	var bottom := HEALTH_BAR_HEIGHT * 0.5
	_health_fill.polygon = PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom),
	])


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()


func _ensure_input_actions() -> void:
	var action_events := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
	}

	for action_name in action_events.keys():
		var action_key := StringName(action_name)
		if not InputMap.has_action(action_key):
			InputMap.add_action(action_key)

		for keycode in action_events[action_name]:
			var event_keycode: int = keycode
			if _action_has_key(action_key, event_keycode):
				continue

			var event := InputEventKey.new()
			event.keycode = event_keycode
			InputMap.action_add_event(action_key, event)


func _action_has_key(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode:
				return true

	return false


func _get_next_xp_threshold(previous_threshold: float) -> float:
	var next_threshold := previous_threshold * maxf(xp_growth_multiplier, 1.0) + maxf(xp_growth_flat, 0.0)
	return ceilf(maxf(next_threshold, previous_threshold + 1.0))


func _queue_upgrade_choices(levels_gained: int) -> void:
	_pending_upgrade_choices += maxi(levels_gained, 0)
	if _is_selecting_upgrade:
		return

	_was_tree_paused_before_level_up = get_tree().paused
	_show_next_upgrade_choice()


func _show_next_upgrade_choice() -> void:
	if _pending_upgrade_choices <= 0:
		get_tree().paused = _was_tree_paused_before_level_up
		return

	_pending_upgrade_choices -= 1
	_is_selecting_upgrade = true
	_ensure_level_up_panel()
	if not is_instance_valid(_level_up_panel):
		_is_selecting_upgrade = false
		get_tree().paused = _was_tree_paused_before_level_up
		return

	_level_up_panel.show_choices(_get_random_upgrade_options())
	get_tree().paused = true


func _ensure_level_up_panel() -> void:
	if is_instance_valid(_level_up_panel):
		return
	if level_up_panel_scene == null:
		push_error("Player has no level_up_panel_scene.")
		return

	var panel_instance := level_up_panel_scene.instantiate()
	if not panel_instance is LevelUpPanel:
		push_error("level_up_panel_scene must instantiate a LevelUpPanel.")
		panel_instance.queue_free()
		return

	_level_up_panel = panel_instance as LevelUpPanel
	_get_level_up_panel_parent().add_child(_level_up_panel)
	_level_up_panel.upgrade_selected.connect(_on_upgrade_selected)


func _get_level_up_panel_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene

	var parent := get_parent()
	if parent != null:
		return parent

	return self


func _get_random_upgrade_options() -> Array[Dictionary]:
	var options := _get_upgrade_pool()
	for i in range(options.size() - 1, 0, -1):
		var swap_index := _upgrade_rng.randi_range(0, i)
		var option := options[i]
		options[i] = options[swap_index]
		options[swap_index] = option

	var selected_options: Array[Dictionary] = []
	for i in range(mini(3, options.size())):
		selected_options.append(options[i])

	return selected_options


func _get_upgrade_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{
			"id": UPGRADE_TALISMAN_DAMAGE,
			"title": "追魂符威力 +10",
			"description": "追魂符击中妖物时伤害提高 10。"
		},
		{
			"id": UPGRADE_TALISMAN_COOLDOWN,
			"title": "追魂符施放 -10%",
			"description": "追魂符出手间隔缩短 10%。"
		},
		{
			"id": UPGRADE_TALISMAN_COUNT,
			"title": "追魂符数量 +1",
			"description": "每次施法额外祭出 1 枚追魂符。"
		},
		{
			"id": UPGRADE_TALISMAN_SPEED,
			"title": "追魂符飞行 +15%",
			"description": "追魂符飞行速度提高 15%。"
		},
		{
			"id": UPGRADE_MAX_HP,
			"title": "气血上限 +20",
			"description": "气血上限提高 20，并回复等量气血。"
		},
		{
			"id": UPGRADE_MOVE_SPEED,
			"title": "身法 +10%",
			"description": "行走身法提升，移动速度提高 10%。"
		},
		{
			"id": UPGRADE_PICKUP_RADIUS,
			"title": "摄取范围 +18",
			"description": "可从更远处吸纳修为灵光。"
		},
		{
			"id": UPGRADE_XP_GAIN,
			"title": "修为获取 +10%",
			"description": "吸收修为灵光时获得的修为提高 10%。"
		}
	]

	if _is_flying_sword_unlocked:
		pool.append({
			"id": UPGRADE_FLYING_SWORD_DAMAGE,
			"title": "飞剑威力 +8",
			"description": "飞剑斩妖伤害提高 8。"
		})
		pool.append({
			"id": UPGRADE_FLYING_SWORD_COOLDOWN,
			"title": "飞剑出鞘 -10%",
			"description": "飞剑出鞘间隔缩短 10%。"
		})
		pool.append({
			"id": UPGRADE_FLYING_SWORD_PIERCE,
			"title": "飞剑贯穿 +1",
			"description": "飞剑可额外贯穿 1 个妖物。"
		})
		pool.append({
			"id": UPGRADE_FLYING_SWORD_COUNT,
			"title": "飞剑数量 +1",
			"description": "每次御剑额外放出 1 柄飞剑。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_FLYING_SWORD,
			"title": "悟得飞剑",
			"description": "唤出飞剑护身，自动追击附近妖物。"
		})

	if _is_thunder_law_unlocked:
		pool.append({
			"id": UPGRADE_THUNDER_LAW_DAMAGE,
			"title": "雷电符咒威力 +10",
			"description": "雷电符咒落雷伤害提高 10。"
		})
		pool.append({
			"id": UPGRADE_THUNDER_LAW_COOLDOWN,
			"title": "雷电符咒施放 -10%",
			"description": "雷电符咒引雷间隔缩短 10%。"
		})
		pool.append({
			"id": UPGRADE_THUNDER_LAW_RADIUS,
			"title": "雷电符咒范围 +16",
			"description": "雷电符咒落雷范围扩大 16。"
		})
		pool.append({
			"id": UPGRADE_THUNDER_LAW_TARGET_COUNT,
			"title": "雷电符咒目标 +1",
			"description": "每次施咒额外轰击 1 个目标。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_THUNDER_LAW,
			"title": "悟得雷电符咒",
			"description": "绘成雷电符咒，轰击聚集的妖物。"
		})

	if _is_bagua_array_unlocked:
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_DAMAGE,
			"title": "八卦阵威力 +6",
			"description": "八卦阵灵光脉冲伤害提高 6。"
		})
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_RADIUS,
			"title": "八卦阵范围 +14",
			"description": "八卦阵伤害范围扩大 14。"
		})
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_ROTATION_SPEED,
			"title": "八卦阵运转 +20%",
			"description": "八卦阵旋转速度提高 20%。"
		})
		pool.append({
			"id": UPGRADE_BAGUA_ARRAY_TICK_RATE,
			"title": "八卦阵脉冲 -10%",
			"description": "八卦阵伤害脉冲间隔缩短 10%。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_BAGUA_ARRAY,
			"title": "悟得八卦阵",
			"description": "布下旋转阵势，持续伤及近身妖物。"
		})

	if _is_explosive_talisman_unlocked:
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_RADIUS,
			"title": "爆裂符范围 +12",
			"description": "爆裂符爆发范围扩大 12。"
		})
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_DAMAGE,
			"title": "爆裂符威力 +8",
			"description": "爆裂符爆发伤害提高 8。"
		})
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_COUNT,
			"title": "爆裂符数量 +1",
			"description": "每次施法额外祭出 1 枚爆裂符。"
		})
		pool.append({
			"id": UPGRADE_EXPLOSIVE_TALISMAN_COOLDOWN,
			"title": "爆裂符施放 -10%",
			"description": "爆裂符施放间隔缩短 10%。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_EXPLOSIVE_TALISMAN,
			"title": "悟得爆裂符",
			"description": "祭出触敌即爆的符箓，震散妖群。"
		})

	if _is_mountain_seal_unlocked:
		pool.append({
			"id": UPGRADE_MOUNTAIN_SEAL_DAMAGE,
			"title": "山河印威力 +16",
			"description": "山河印砸落伤害提高 16。"
		})
		pool.append({
			"id": UPGRADE_MOUNTAIN_SEAL_RADIUS,
			"title": "山河印范围 +18",
			"description": "山河印砸落范围扩大 18。"
		})
		pool.append({
			"id": UPGRADE_MOUNTAIN_SEAL_COOLDOWN,
			"title": "山河印显化 -10%",
			"description": "山河印显化间隔缩短 10%。"
		})
	else:
		pool.append({
			"id": UPGRADE_UNLOCK_MOUNTAIN_SEAL,
			"title": "悟得山河印",
			"description": "凝出重印镇落，压制大片妖物。"
		})

	return pool


func _on_upgrade_selected(upgrade_id: StringName) -> void:
	_apply_upgrade(upgrade_id)
	if is_instance_valid(_level_up_panel):
		_level_up_panel.hide_panel()

	_is_selecting_upgrade = false
	if _pending_upgrade_choices > 0:
		_show_next_upgrade_choice()
	else:
		get_tree().paused = _was_tree_paused_before_level_up


func _apply_upgrade(upgrade_id: StringName) -> void:
	match upgrade_id:
		UPGRADE_TALISMAN_DAMAGE:
			if _talisman_weapon != null:
				_talisman_weapon.damage += 10.0
		UPGRADE_TALISMAN_COOLDOWN:
			if _talisman_weapon != null:
				_talisman_weapon.cooldown = maxf(_talisman_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_TALISMAN_COUNT:
			if _talisman_weapon != null:
				_talisman_weapon.projectile_count += 1
		UPGRADE_TALISMAN_SPEED:
			if _talisman_weapon != null:
				_talisman_weapon.projectile_speed *= 1.15
		UPGRADE_UNLOCK_FLYING_SWORD:
			_is_flying_sword_unlocked = true
			_set_weapon_unlocked(_flying_sword_weapon, true)
		UPGRADE_FLYING_SWORD_DAMAGE:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.damage += 8.0
		UPGRADE_FLYING_SWORD_COOLDOWN:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.cooldown = maxf(_flying_sword_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_FLYING_SWORD_PIERCE:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.pierce_count += 1
		UPGRADE_FLYING_SWORD_COUNT:
			if _flying_sword_weapon != null:
				_flying_sword_weapon.projectile_count += 1
		UPGRADE_UNLOCK_THUNDER_LAW:
			_is_thunder_law_unlocked = true
			_set_weapon_unlocked(_thunder_law_weapon, true)
		UPGRADE_THUNDER_LAW_DAMAGE:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.damage += 10.0
		UPGRADE_THUNDER_LAW_COOLDOWN:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.cooldown = maxf(_thunder_law_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_THUNDER_LAW_RADIUS:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.radius += 16.0
		UPGRADE_THUNDER_LAW_TARGET_COUNT:
			if _thunder_law_weapon != null:
				_thunder_law_weapon.target_count += 1
		UPGRADE_UNLOCK_BAGUA_ARRAY:
			_is_bagua_array_unlocked = true
			_set_weapon_unlocked(_bagua_array_weapon, true)
		UPGRADE_BAGUA_ARRAY_DAMAGE:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.damage += 6.0
		UPGRADE_BAGUA_ARRAY_RADIUS:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.radius += 14.0
		UPGRADE_BAGUA_ARRAY_ROTATION_SPEED:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.rotation_speed *= 1.2
		UPGRADE_BAGUA_ARRAY_TICK_RATE:
			if _bagua_array_weapon != null:
				_bagua_array_weapon.tick_rate = maxf(_bagua_array_weapon.tick_rate * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_UNLOCK_EXPLOSIVE_TALISMAN:
			_is_explosive_talisman_unlocked = true
			_set_weapon_unlocked(_explosive_talisman_weapon, true)
		UPGRADE_EXPLOSIVE_TALISMAN_RADIUS:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.explosion_radius += 12.0
		UPGRADE_EXPLOSIVE_TALISMAN_DAMAGE:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.explosion_damage += 8.0
		UPGRADE_EXPLOSIVE_TALISMAN_COUNT:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.projectile_count += 1
		UPGRADE_EXPLOSIVE_TALISMAN_COOLDOWN:
			if _explosive_talisman_weapon != null:
				_explosive_talisman_weapon.cooldown = maxf(_explosive_talisman_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_UNLOCK_MOUNTAIN_SEAL:
			_is_mountain_seal_unlocked = true
			_set_weapon_unlocked(_mountain_seal_weapon, true)
		UPGRADE_MOUNTAIN_SEAL_DAMAGE:
			if _mountain_seal_weapon != null:
				_mountain_seal_weapon.damage += 16.0
		UPGRADE_MOUNTAIN_SEAL_RADIUS:
			if _mountain_seal_weapon != null:
				_mountain_seal_weapon.radius += 18.0
		UPGRADE_MOUNTAIN_SEAL_COOLDOWN:
			if _mountain_seal_weapon != null:
				_mountain_seal_weapon.cooldown = maxf(_mountain_seal_weapon.cooldown * 0.9, WeaponBase.MIN_COOLDOWN)
		UPGRADE_MAX_HP:
			max_hp += 20.0
			current_hp = minf(current_hp + 20.0, max_hp)
			_update_health_bar()
			health_changed.emit(current_hp, max_hp)
		UPGRADE_MOVE_SPEED:
			move_speed *= 1.1
		UPGRADE_PICKUP_RADIUS:
			pickup_radius_bonus += 18.0
		UPGRADE_XP_GAIN:
			xp_gain_multiplier *= 1.1
		_:
			push_warning("Unknown upgrade selected: %s" % String(upgrade_id))
			return

	upgrade_applied.emit(upgrade_id)


func _set_weapon_unlocked(weapon: WeaponBase, is_unlocked: bool) -> void:
	if weapon == null:
		return

	if is_unlocked:
		weapon.process_mode = Node.PROCESS_MODE_INHERIT
		weapon.visible = true
	else:
		weapon.process_mode = Node.PROCESS_MODE_DISABLED
		weapon.visible = false
