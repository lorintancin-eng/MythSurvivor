class_name YangJian
extends CharacterBase

## 二郎真君（v0.2，全自动战斗角色）
##
## 专属能量：天眼槽（时间自动充能 + 击杀充能，满时标记就绪）
## 详见 docs/NEZHA_YANGJIAN_DESIGN.md §3
##
## 不是 ActiveSkillCharacter，战斗全自动。
## 天眼槽满时设置 _eye_ready = true（不自动消耗）。
## 三尖两刃刀调用 consume_heaven_eye() 触发天眼一斩。

const MAX_HEAVEN_EYE: float = 100.0
const TIME_CHARGE_RATE: float = 2.0  # per second
const KILL_CHARGE_NORMAL: float = 3.0
const KILL_CHARGE_ELITE: float = 30.0

var current_heaven_eye: float = 0.0
var _eye_ready: bool = false

## 升级时可写入以调整充能速率
var eye_kill_charge: float = KILL_CHARGE_NORMAL
var eye_time_rate: float = TIME_CHARGE_RATE


func _ready() -> void:
	if character_id == "":
		character_id = "yang_jian"
	if display_name == "":
		display_name = "二郎真君"
	if energy_bar_config.is_empty():
		energy_bar_config = {
			"max_value": MAX_HEAVEN_EYE,
			"fill_color": Color(0.8, 0.9, 1.0),
			"label": "天眼槽",
			"auto_trigger": false,
			"value_field": "current_heaven_eye",
		}


func _process(delta: float) -> void:
	if _eye_ready:
		return
	current_heaven_eye = minf(current_heaven_eye + eye_time_rate * delta, MAX_HEAVEN_EYE)
	if current_heaven_eye >= MAX_HEAVEN_EYE:
		_on_energy_full()


## 击杀敌人时充能天眼槽（CharacterBase override）
## player.gd 的 _on_enemy_killed 通过 EnemySpawner.enemy_killed 信号转发此方法
func _on_kill(enemy: Node) -> void:
	if _eye_ready:
		return
	var charge := eye_kill_charge
	if enemy != null and enemy.get("is_elite") == true:
		charge = KILL_CHARGE_ELITE
	current_heaven_eye = minf(current_heaven_eye + charge, MAX_HEAVEN_EYE)
	if current_heaven_eye >= MAX_HEAVEN_EYE:
		_on_energy_full()


## 天眼槽满时标记就绪（CharacterBase override）
## auto_trigger = false：不自动消耗，等待武器主动查询
func _on_energy_full() -> void:
	_eye_ready = true
	energy_full_triggered.emit()


## 武器攻击前查询：消耗天眼槽触发天眼一斩
## 返回 true 表示本次攻击使用天眼（武器造成即死/强化伤害），并清零能量
## 返回 false 表示天眼未就绪，正常攻击
func consume_heaven_eye() -> bool:
	if not _eye_ready:
		return false
	_eye_ready = false
	current_heaven_eye = 0.0
	# 通知 HUD 清零（复用 energy_full_triggered 作为视觉脉冲信号）
	energy_full_triggered.emit()
	return true


## 升级池过滤（Y05 任务接入升级项后填充）
func _get_allowed_upgrade_ids() -> Array[String]:
	return []
