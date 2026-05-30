class_name TerrainEffect
extends Area2D

## 地形效果区域（L003 G01，v0.6 新机制；v0.7 扩展 BURN/SNARE/CURSE）
##
## 决策 D1：Area2D 信号 + Player 统一 apply_terrain_effect(type, duration)
## 决策 D2：v0.6 只支持 SLOW + BLINK（不做 HASTE）
## 决策 D3：v0.7 增加 BURN（持续伤害）、SNARE（完全定身）、CURSE（减少 XP）
##
## 用法：
##   1. 在 .tscn 中放置 TerrainEffect 节点
##   2. 在 Inspector 配置 effect_type / duration / radius / color
##   3. 玩家进入触发 apply_terrain_effect 给 Player
##   4. SLOW/BURN/SNARE/CURSE: 离开时调用 remove_terrain_effect
##   5. BLINK: 进入瞬间触发瞬移 + cooldown 1s 防连击

enum Type {
	SLOW,    # 减速 65%（玩家移速倍率 0.65）
	BLINK,   # 闪烁瞬移（随机方向 60-100px，一次性）
	BURN,    # 持续伤害 DOT（默认 6 DPS）
	SNARE,   # 完全定身（移速 0）
	CURSE,   # 减少 XP 获取（×0.70）
}

@export var effect_type: Type = Type.SLOW
@export var duration: float = 0.0  # SLOW/BURN/SNARE/CURSE: 0 = 持续直到离开；BLINK 忽略
@export var effect_radius: float = 60.0
@export var slow_color: Color = Color(0.3, 0.2, 0.5, 0.35)
@export var blink_color: Color = Color(0.2, 0.5, 0.95, 0.5)
@export var burn_color: Color = Color(0.85, 0.3, 0.05, 0.45)
@export var snare_color: Color = Color(0.7, 0.5, 0.95, 0.45)
@export var curse_color: Color = Color(0.2, 0.65, 0.15, 0.40)
@export var blink_cooldown: float = 1.0
@export var blink_min_distance: float = 60.0
@export var blink_max_distance: float = 100.0
@export var burn_dps: float = 6.0

var _blink_cooldown_timer: float = 0.0
var _draw_pulse_phase: float = 0.0


func _ready() -> void:
	add_to_group("terrain_effects")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 设置碰撞 shape
	var shape := CircleShape2D.new()
	shape.radius = effect_radius
	var coll := CollisionShape2D.new()
	coll.shape = shape
	add_child(coll)


func _process(delta: float) -> void:
	_blink_cooldown_timer = maxf(_blink_cooldown_timer - delta, 0.0)
	if effect_type == Type.BLINK:
		_draw_pulse_phase += delta * 3.0
		queue_redraw()


func _draw() -> void:
	var color: Color
	match effect_type:
		Type.SLOW:
			color = slow_color
		Type.BLINK:
			color = blink_color
			var pulse := 0.5 + 0.5 * sin(_draw_pulse_phase)
			color.a = blink_color.a * (0.5 + 0.5 * pulse)
		Type.BURN:
			color = burn_color
		Type.SNARE:
			color = snare_color
		Type.CURSE:
			color = curse_color
		_:
			color = slow_color
	var pts := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2.RIGHT.rotated(ang) * effect_radius)
	draw_colored_polygon(pts, color)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("apply_terrain_effect"):
		return
	match effect_type:
		Type.SLOW:
			body.apply_terrain_effect(Type.SLOW, duration)
		Type.BLINK:
			if _blink_cooldown_timer > 0.0:
				return
			_blink_cooldown_timer = blink_cooldown
			_do_blink(body)
		Type.BURN:
			body.apply_terrain_effect(Type.BURN, duration, burn_dps)
		Type.SNARE:
			body.apply_terrain_effect(Type.SNARE, duration)
		Type.CURSE:
			body.apply_terrain_effect(Type.CURSE, duration)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# BLINK 是一次性触发，无需 remove
	if effect_type == Type.BLINK:
		return
	if not body.has_method("remove_terrain_effect"):
		return
	body.remove_terrain_effect(effect_type)


func _exit_tree() -> void:
	# 节点销毁时，若玩家仍在区域内，移除其 buff（防 BURN/SLOW/SNARE/CURSE 残留）
	# BLINK 是一次性触发，无需处理
	if effect_type == Type.BLINK:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("remove_terrain_effect"):
			body.remove_terrain_effect(effect_type)


func _do_blink(player: Node) -> void:
	if not player is Node2D:
		return
	var p := player as Node2D
	var dist := randf_range(blink_min_distance, blink_max_distance)
	var angle := randf() * TAU
	var offset := Vector2.RIGHT.rotated(angle) * dist
	p.global_position += offset
