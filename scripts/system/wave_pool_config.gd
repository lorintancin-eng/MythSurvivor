class_name WavePoolConfig
extends Resource

## 单个 wave 的怪物池配置
## 由 StageConfig.wave_pools 数组持有（5 项对应 index 0-4）

@export var archetypes: Array[Resource] = []
@export var weights: Array[float] = []
