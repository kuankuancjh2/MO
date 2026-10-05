class_name BalanceData
extends Resource
## 手感 / 平衡参数集中地。
## 运行时会从 res://data/balance.tres 读取；文件缺失则使用本文件的默认值。

@export_group("世界")
@export var tile_size: int = 48

@export_group("世界种子")
## 0 = 每次开局随机；非 0 = 固定种子（便于调试复现）
@export var fixed_world_seed: int = 0

@export_group("主角")
@export var player_size: int = 32
@export var player_max_hp: int = 5
@export var move_speed: float = 250.0
@export var accel: float = 2400.0
@export var friction: float = 2800.0
@export var gravity: float = 1500.0
@export var max_fall_speed: float = 950.0
@export var jump_velocity: float = -520.0
@export var jump_cut_factor: float = 0.45
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12

@export_group("地面消失")
## 核心手感参数：踩上去后多少秒消失
@export var vanish_time: float = 4.0
## 消失动画的三段占比 —— 变色 / 闪烁 / 消散
@export var vanish_warn_ratio: float = 0.60
@export var vanish_blink_ratio: float = 0.30

@export_group("攻击")
@export var attack_cooldown: float = 0.30
@export var attack_damage: float = 1.0
@export var projectile_speed: float = 640.0
@export var projectile_life: float = 0.50

@export_group("掉落伤害")
## 只有掉落超过这个高度（以格子计）才会受伤
@export var fall_damage_min_tiles: float = 4.5
## 超过阈值后，每多掉一格造成的伤害
@export var fall_damage_per_tile: float = 0.30
## 单次掉落伤害上限（不多）
@export var fall_damage_max: float = 1.5
## 掉落伤害是否可以致死。false = 摔不死，最多剩 1 心。
@export var fall_damage_lethal: bool = false

@export_group("敌人")
@export var enemy_hp: float = 2.0
@export var enemy_damage: float = 1.0
@export var enemy_speed: float = 68.0
@export var enemy_contact_cooldown: float = 0.8
@export var enemy_spawn_chance: float = 0.045
@export var radical_spawn_chance: float = 0.012

@export_group("偏旁")
@export var radical_slots_base: int = 2
@export var attract_radius: float = 230.0
@export var attract_speed: float = 420.0
@export var enemy_attract_speed: float = 26.0

@export_group("关卡")
@export var world_cols: int = 24
@export var world_rows: int = 18
