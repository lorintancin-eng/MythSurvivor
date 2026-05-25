class_name GhostOfficer
extends RangedEnemy

## 鬼差（L002 D03，远程攻击）
##
## 继承 RangedEnemy，使用 @export 字段定制数值。
## 所有行为由 RangedEnemy 基类提供：
## - attack_range / preferred_distance 控制站位
## - projectile_damage / projectile_speed 控制弹药
## - fire_interval 控制射击频率
##
## 数值在 archetype/scene 中覆盖，此脚本仅作类型标识。
## 设计参考 docs/L002_GHOST_MARKET_DESIGN.md §4.2
