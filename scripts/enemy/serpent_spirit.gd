class_name SerpentSpirit
extends RangedEnemy

## Serpent Spirit (L003 G05, ranged enemy)
##
## Inherits RangedEnemy; all behavior provided by the base class.
## Stats per design doc §4.2:
##   hp 38 / speed 64 / contact 9 / xp 14
##   attack_range 220 / preferred_distance 160 / distance_band 30
##   projectile_damage 7 / projectile_speed 240 / fire_interval 2.8
##   projectile_color Color(0.4, 0.85, 0.6, 0.9)  — jade green
##
## v0.6 MVP: single shot per interval.
## burst_count 1-3 variation deferred to v0.7.
##
## Difference from GhostOfficer: longer fire_interval but higher
## projectile_speed, making each shot a higher-threat single hit.
