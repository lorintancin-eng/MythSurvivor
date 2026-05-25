class_name StageConfig
extends Resource

## 单关卡完整配置（L001 / L002 / L003 各一份 .tres）
## 由 StageDirector 加载，决定所有 wave / Boss / 镇妖碑参数

## 关卡标识
@export_group("Identity")
@export var stage_id: String = "stage_01_huangshan"
@export var stage_name: String = "一·荒山古道"
@export var stage_duration: float = 300.0

## Wave 时间节点（s）
@export_group("Wave Timing")
@export var wave_two_start_time: float = 60.0
@export var wave_three_start_time: float = 120.0
@export var wave_four_start_time: float = 180.0
@export var wave_boss_warning_start_time: float = 270.0

## Wave 间隔 + 上限（5 个数组，对应 wave_config_index 0-4）
@export_group("Wave Spawn")
@export var wave_spawn_intervals: Array[float] = [1.35, 1.08, 0.90, 0.72, 0.55]
@export var wave_max_enemies: Array[int] = [18, 24, 32, 42, 56]
@export var wave_pools: Array[WavePoolConfig] = []  # 5 项

## Boss
@export_group("Boss")
@export var boss_scene: PackedScene
@export var boss_warning_lead_time: float = 30.0
@export var boss_spawn_distance: float = 420.0
@export var boss_move_speed: float = 70.0
@export var boss_max_hp: float = 260.0
@export var boss_damage: float = 16.0
@export var boss_scale: float = 1.8
@export var boss_phase_spawn_interval: float = 2.5
@export var boss_phase_max_enemies: int = 8

## 镇妖碑
@export_group("Demon Seal")
@export var demon_seal_scene: PackedScene
@export var demon_seal_spawn_time: float = 120.0
@export var demon_seal_min_spawn_distance: float = 200.0
@export var demon_seal_max_spawn_distance: float = 280.0
@export var demon_seal_required_seconds: float = 8.0
@export var demon_seal_pressure_interval_multiplier: float = 0.65
@export var demon_seal_pressure_max_enemy_bonus: int = 6
@export var demon_seal_reward_orb_count: int = 8
@export var demon_seal_reward_xp_value: float = 6.0
@export var demon_seal_reward_radius: float = 54.0

## 精英
@export_group("Elite")
@export var first_elite_spawn_time: float = 180.0
@export var second_elite_spawn_time: float = 240.0
@export var elite_spawn_distance: float = 420.0

## 场景
@export_group("Scenes")
@export var experience_orb_scene: PackedScene
