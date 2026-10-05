class_name BalanceData
extends Resource
## 手感 / 平衡参数集中地。
## 运行时会从 res://data/balance.tres 读取；文件缺失则使用本文件的默认值。
##
## 注意：Godot 只把「和默认值不同」的项写进 .tres，所以那个文件很短，这是正常的。

@export_group("渲染 / 过采样")
## ★ 过采样：素材是原生 128px，而本文件里的像素数值是按「48px 格子」调的调参单位。
## 打开后 Balance 会在加载时把所有"像素长度"统一乘 art_tile_size/48，
## 同时相机 zoom 拉回倒数 —— 于是视觉布局、跳跃格数、手感完全不变，
## 但素材以 1:1 原生尺寸进渲染管线（相当于做了一次 SSAA）。
## 以「格」为单位的数值（掉落阈值、刷新距离…）和「秒」为单位的数值都不受影响。
@export var oversample: bool = true
## 素材原生格子尺寸（缩放比 = 它 / 48）
@export var art_tile_size: int = 128

@export_group("世界")
@export var tile_size: int = 48
## 0 = 每次开局随机种子；非 0 = 固定种子（便于复现调试）
@export var fixed_world_seed: int = 0
@export var world_cols: int = 24
@export var world_rows: int = 18

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
## 核心手感参数：踩上去后多少秒消失（调快 = 地面碎得更急，更逼你往前跑）
@export var vanish_time: float = 2.6
## 消失动画三段占比 —— 变色 / 闪烁 / 消散
@export var vanish_warn_ratio: float = 0.60
@export var vanish_blink_ratio: float = 0.30

@export_group("攻击")
@export var attack_cooldown: float = 0.28
@export var attack_damage: float = 1.0
@export var projectile_speed: float = 680.0
@export var projectile_life: float = 0.55

@export_group("掉落伤害")
## 低于这个高度完全没事（普通起跳 1.88 格，永不触发）
@export var fall_safe_tiles: float = 4.5
## 低于这个高度可以靠「落地前按跳跃」卸力免伤；再高就免不掉了
@export var fall_cancel_max_tiles: float = 10.0
## 落地前多少秒内按过跳跃算作卸力成功
@export var fall_landing_cancel_window: float = 0.22
## 触发时的伤害（固定 1 心，上限低）
@export var fall_damage_amount: float = 1.0
## 掉落伤害是否可以致死。false = 摔不死，最多剩 1 心。
@export var fall_damage_lethal: bool = false

@export_group("敌人")
@export var enemy_hp: float = 2.0
@export var enemy_damage: float = 1.0
@export var enemy_speed: float = 68.0
@export var enemy_contact_cooldown: float = 0.8
## 踩头弹起的力度
@export var stomp_bounce: float = -420.0
## 每格平台上刷怪的独立概率（密度故意压得很低）
@export var enemy_spawn_chance: float = 0.010      ## 红色方块怪（巡逻）
@export var seeker_spawn_chance: float = 0.004     ## 猎手（追人）
@export var flyer_spawn_chance: float = 0.005      ## 飞怪
@export var radical_enemy_chance: float = 0.006    ## 红色偏旁怪
@export var word_block_spawn_chance: float = 0.010 ## 地上的字块
## 离主角多近之内不刷怪（格）
@export var spawn_min_distance: int = 8

@export_group("敌人：飞怪")
@export var flyer_speed: float = 82.0
@export var flyer_tame_time: float = 6.0

@export_group("字 / 偏旁")
@export var radical_slots_base: int = 2
@export var attract_radius: float = 230.0
@export var attract_speed: float = 420.0
@export var enemy_attract_speed: float = 26.0

@export_group("商店")
@export var shop_heal_price: int = 2
@export var shop_word_price: int = 5
@export var shop_slot_price: int = 8

@export_group("Boss「有」")
@export var boss_hp: float = 20.0
@export var boss_contact_damage: float = 1.0
@export var boss_shot_damage: float = 1.0
@export var boss_shot_speed: float = 420.0
