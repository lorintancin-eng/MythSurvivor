class_name WaterFlowZone
extends Area2D

## 水流区域（L004+ 东海等关卡地形）
##
## 玩家进入后每帧施加水流方向推力，离开后推力自然衰减（由 Player._water_push_velocity lerp 实现）
## 使用：在场景中放置 WaterFlowZone，配置 flow_direction / flow_strength，
##        搭配 CollisionShape2D 决定覆盖范围

@export var flow_direction: Vector2 = Vector2.RIGHT
@export var flow_strength: float = 80.0
@export var zone_color: Color = Color(0.2, 0.5, 0.85, 0.3)

var _bodies_inside: Array = []


func _ready() -> void:
	collision_mask = 1
	body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_bodies_inside.append(b)
	)
	body_exited.connect(func(b: Node) -> void:
		_bodies_inside.erase(b)
	)


func _physics_process(delta: float) -> void:
	# duplicate 防御：body_exited 信号可能在迭代中修改 _bodies_inside
	for b in _bodies_inside.duplicate():
		if is_instance_valid(b) and b.has_method("apply_water_push"):
			b.apply_water_push(flow_direction.normalized() * flow_strength * delta)


func _draw() -> void:
	draw_rect(Rect2(-80.0, -40.0, 160.0, 80.0), zone_color)
