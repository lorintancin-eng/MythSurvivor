class_name StageRegistry
extends RefCounted

## 关卡注册表（v0.5 新增）
## 静态查询接口，提供：
## - get_stage(stage_id) 加载指定关卡配置
## - get_next_stage_id(current_stage_id) 关卡链顺序（生存模式核心）
## - get_first_stage_id() 起始关卡
##
## 关卡链：L001 → L002 → L003 → null（游戏通关）

const STAGE_001_PATH: String = "res://resources/stages/stage_01_huangshan.tres"
const STAGE_002_PATH: String = "res://resources/stages/stage_02_ghost_market.tres"
const STAGE_003_PATH: String = "res://resources/stages/stage_03_kunlun.tres"

## 关卡链顺序：当前关卡 id → 下一关 id
const STAGE_CHAIN: Dictionary = {
	"stage_01_huangshan": "stage_02_ghost_market",
	"stage_02_ghost_market": "stage_03_kunlun",
	"stage_03_kunlun": "",
}

## 关卡 id → 资源路径
const STAGE_PATHS: Dictionary = {
	"stage_01_huangshan": STAGE_001_PATH,
	"stage_02_ghost_market": STAGE_002_PATH,
	"stage_03_kunlun": STAGE_003_PATH,
}


## 加载指定关卡配置；找不到或资源不存在时返回 null
static func get_stage(stage_id: String) -> StageConfig:
	if not STAGE_PATHS.has(stage_id):
		push_warning("StageRegistry.get_stage: unknown stage_id %s" % stage_id)
		return null
	var path: String = STAGE_PATHS[stage_id]
	if not ResourceLoader.exists(path):
		push_warning("StageRegistry.get_stage: resource not found at %s" % path)
		return null
	var resource = load(path)
	if not (resource is StageConfig):
		push_warning("StageRegistry.get_stage: %s is not a StageConfig" % path)
		return null
	return resource as StageConfig


## 返回下一关 id；通关或未知关卡返回空字符串
static func get_next_stage_id(current_stage_id: String) -> String:
	if not STAGE_CHAIN.has(current_stage_id):
		return ""
	return STAGE_CHAIN[current_stage_id]


## 起始关卡
static func get_first_stage_id() -> String:
	return "stage_01_huangshan"


## 查询关卡是否存在（不一定有资源文件）
static func is_known_stage(stage_id: String) -> bool:
	return STAGE_PATHS.has(stage_id)
