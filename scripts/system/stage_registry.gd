class_name StageRegistry
extends RefCounted

## 关卡注册表（v0.5 新增；v0.7 扩展至 10 关）
## 静态查询接口，提供：
## - get_stage(stage_id) 加载指定关卡配置
## - get_next_stage_id(current_stage_id) 关卡链顺序（生存模式核心）
## - get_first_stage_id() 起始关卡
##
## 关卡链：L001 → L002 → L003 → L004 → … → L010 → ""（游戏通关）
## L004-L010 .tres 渐进补充；未完成的关卡 get_stage 返回 null → StageDirector 弹 VictoryPanel

const STAGE_001_PATH: String = "res://resources/stages/stage_01_huangshan.tres"
const STAGE_002_PATH: String = "res://resources/stages/stage_02_ghost_market.tres"
const STAGE_003_PATH: String = "res://resources/stages/stage_03_kunlun.tres"
const STAGE_004_PATH: String = "res://resources/stages/stage_04_east_sea.tres"
const STAGE_005_PATH: String = "res://resources/stages/stage_05_flame_mountain.tres"
const STAGE_006_PATH: String = "res://resources/stages/stage_06_spider_ridge.tres"
const STAGE_007_PATH: String = "res://resources/stages/stage_07_yellow_wind.tres"
const STAGE_008_PATH: String = "res://resources/stages/stage_08_fengdu.tres"
const STAGE_009_PATH: String = "res://resources/stages/stage_09_heavenly_palace.tres"
const STAGE_010_PATH: String = "res://resources/stages/stage_10_lingshan.tres"

## 关卡链顺序：当前关卡 id → 下一关 id
const STAGE_CHAIN: Dictionary = {
	"stage_01_huangshan": "stage_02_ghost_market",
	"stage_02_ghost_market": "stage_03_kunlun",
	"stage_03_kunlun": "stage_04_east_sea",
	"stage_04_east_sea": "stage_05_flame_mountain",
	"stage_05_flame_mountain": "stage_06_spider_ridge",
	"stage_06_spider_ridge": "stage_07_yellow_wind",
	"stage_07_yellow_wind": "stage_08_fengdu",
	"stage_08_fengdu": "stage_09_heavenly_palace",
	"stage_09_heavenly_palace": "stage_10_lingshan",
	"stage_10_lingshan": "",
}

## 关卡 id → 资源路径
const STAGE_PATHS: Dictionary = {
	"stage_01_huangshan": STAGE_001_PATH,
	"stage_02_ghost_market": STAGE_002_PATH,
	"stage_03_kunlun": STAGE_003_PATH,
	"stage_04_east_sea": STAGE_004_PATH,
	"stage_05_flame_mountain": STAGE_005_PATH,
	"stage_06_spider_ridge": STAGE_006_PATH,
	"stage_07_yellow_wind": STAGE_007_PATH,
	"stage_08_fengdu": STAGE_008_PATH,
	"stage_09_heavenly_palace": STAGE_009_PATH,
	"stage_10_lingshan": STAGE_010_PATH,
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
