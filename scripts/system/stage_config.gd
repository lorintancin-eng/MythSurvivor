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

## 视觉主题（v0.5 补点 — L002 设计稿 §5.3）
## 关卡过渡时由 RenderingServer.set_default_clear_color 应用
## L001 暗绿黑 / L002 紫黑 / L003 蓝黑（v0.6）
@export_group("Theme")
@export var background_color: Color = Color(0.08, 0.10, 0.06, 1.0)

## 地形效果（L003 G01；count=0 = 不 spawn，L001/L002 留 0）
@export_group("Terrain")
@export var terrain_effect_scene: PackedScene
@export var terrain_effect_count: int = 0
## 每个地形的类型（0=SLOW 1=BLINK 2=BURN 3=SNARE 4=CURSE），与 count 等长；空数组则全 SLOW
@export var terrain_effect_types: Array[int] = []
@export var terrain_effect_min_spawn_distance: float = 200.0
@export var terrain_effect_max_spawn_distance: float = 600.0

## 可破坏物件（L003 G02；count=0 = 不 spawn）
@export_group("Breakables")
@export var breakable_scene: PackedScene
@export var breakable_count: int = 0
@export var breakable_min_spawn_distance: float = 180.0
@export var breakable_max_spawn_distance: float = 500.0

## 出怪视口缩减因子（L004+ 多路线关卡用；默认 1.0 = 全视口，L001-L003 无影响）
@export_group("Spawner")
@export var viewport_reduction_factor: float = 1.0
