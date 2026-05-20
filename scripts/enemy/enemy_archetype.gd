class_name EnemyArchetype
extends Resource

enum MovementMode {
	CHASE,
	WAVE_CHASE,
}

@export var display_name: String = "Wandering Soul"
@export var max_hp: float = 24.0
@export var move_speed: float = 90.0
@export var damage: float = 8.0
@export var damage_interval: float = 0.8
@export var xp_drop_value: float = 5.0
@export var body_color: Color = Color(0.73, 0.24, 0.28, 1.0)
@export var body_scale: float = 1.0
@export var collision_radius: float = 11.0
@export var damage_radius: float = 15.0
@export var health_bar_y: float = -24.0
@export var movement_mode: MovementMode = MovementMode.CHASE
@export var wave_amplitude: float = 0.0
@export var wave_frequency: float = 0.0
@export var wave_phase: float = 0.0
