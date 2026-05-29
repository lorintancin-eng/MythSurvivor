class_name Nezha
extends CharacterBase

## 哪吒「火劫童子」（v0.6，全自动战斗角色）
##
## 专属能量：三昧真火（受伤累积，满时下次攻击爆发）
## 详见 docs/NEZHA_YANGJIAN_DESIGN.md §2
##
## 不是 ActiveSkillCharacter，战斗全自动（模式接近修行者）。
## 三昧真火由 _on_damaged 充能，火尖枪调用 consume_fire() 触发爆发。

const MAX_TRUE_FIRE: float = 100.0
const FIRE_CHARGE_PER_HIT: float = 10.0
const FIRE_BURST_DAMAGE_MULT: float = 1.3
const FIRE_BURST_RANGE_MULT: float = 1.5

var current_true_fire: float = 0.0
var _fire_ready: bool = false
# 上一帧记录的 HP，用于判断是否受伤（HP 减少）
var _last_known_hp: float = -1.0

## N05 升级接入时可调（由升级项写入）
var fire_charge_amount: float = FIRE_CHARGE_PER_HIT
var fire_burst_range_mult: float = FIRE_BURST_RANGE_MULT


func _ready() -> void:
	if character_id == "":
		character_id = "nezha"
	if display_name == "":
		display_name = "火劫童子"
	if energy_bar_config.is_empty():
		energy_bar_config = {
			"max_value": MAX_TRUE_FIRE,
			"fill_color": Color(1.0, 0.3, 0.0),
			"label": "三昧真火",
			"auto_trigger": false,
			"value_field": "current_true_fire",
		}
	# player.gd 的 take_damage 不转发 _character_base._on_damaged，
	# 通过订阅 Player.health_changed 信号实现受伤监听（HP 下降即受伤）。
	var player := get_parent()
	if player != null and player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)


## 监听 Player 血量变化，HP 减少时累积三昧真火
func _on_player_health_changed(current_hp: float, _max_hp: float) -> void:
	# 初始化：记录首次 HP 值，不触发充能
	if _last_known_hp < 0.0:
		_last_known_hp = current_hp
		return
	# 仅在 HP 减少（受伤）时充能
	if current_hp < _last_known_hp:
		_on_damaged(_last_known_hp - current_hp)
	_last_known_hp = current_hp


## 受伤时累积三昧真火（CharacterBase override）
## 已就绪时不再充能，避免浪费
func _on_damaged(amount: float) -> void:
	if _fire_ready:
		return
	current_true_fire = minf(current_true_fire + fire_charge_amount, MAX_TRUE_FIRE)
	if current_true_fire >= MAX_TRUE_FIRE:
		_on_energy_full()


## 能量满时设置爆发就绪标记（CharacterBase override）
func _on_energy_full() -> void:
	_fire_ready = true
	energy_full_triggered.emit()


## 武器攻击前查询：消耗三昧真火触发爆发
## 返回 true 表示本次攻击爆发（武器应叠加伤害/范围倍率），并清零能量
## 返回 false 表示尚未就绪，正常攻击
func consume_fire() -> bool:
	if not _fire_ready:
		return false
	_fire_ready = false
	current_true_fire = 0.0
	# 通知 HUD 清零显示（energy_full_triggered 同时用于充满和清零的视觉脉冲）
	energy_full_triggered.emit()
	return true


## 当前爆发伤害倍率（武器用）
func get_fire_damage_mult() -> float:
	return FIRE_BURST_DAMAGE_MULT


## 当前爆发范围倍率（武器用，可被升级覆盖）
func get_fire_range_mult() -> float:
	return fire_burst_range_mult


## 升级池过滤（N05：返回哪吒专属升级 ID，player.gd 自动补充通用 4 项）
func _get_allowed_upgrade_ids() -> Array[String]:
	return [
		"nezha_fire_spear_damage",
		"nezha_fire_spear_cooldown",
		"nezha_fire_spear_burn",
		"nezha_hun_tian_ling_radius",
		"nezha_hun_tian_ling_dot",
		"nezha_hun_tian_ling_cooldown",
		"nezha_qian_kun_damage",
		"nezha_qian_kun_cooldown",
		"nezha_true_fire_charge",
		"nezha_true_fire_burst_range",
		"nezha_unlock_hun_tian_ling",
		"nezha_unlock_qian_kun",
	]
