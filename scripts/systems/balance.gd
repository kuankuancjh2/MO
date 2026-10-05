extends Node
## 手感/平衡参数单例。优先读 res://data/balance.tres，缺失则用代码默认值。
##
## ★ 过采样：balance.tres 里的像素数值是按「48px 格子」调的调参单位。
## 加载后会把所有像素长度统一乘 128/48（= 素材原生尺寸 / 调参单位），
## 相机 zoom 再拉回 128/48 的倒数 —— 视觉与手感完全不变，
## 但素材以 1:1 原生尺寸进入渲染管线（等于做了一次过采样）。
##
## 好处：所有调用点（`b.move_speed` / `b.gravity` / `b.tile_size`…）一行都不用改。

const CONFIG_PATH := "res://data/balance.tres"
const TUNE_TILE := 48.0        ## 调参单位：本文件里像素数值对应的格子尺寸

var d: BalanceData
## 像素缩放比（= art_tile_size / 48）。绘制代码里的硬编码像素尺寸乘它即可。
var px: float = 1.0


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		d = load(CONFIG_PATH) as BalanceData
	if d == null:
		d = BalanceData.new()
		push_warning("MO: data/balance.tres 不存在，使用代码默认参数。")
	if d.oversample:
		px = float(d.art_tile_size) / TUNE_TILE
		_scale_pixels(px)


## 把「像素长度」类的字段全部乘 k。时间类（秒）、格数类、心的数量都不动。
func _scale_pixels(k: float) -> void:
	if is_equal_approx(k, 1.0):
		return
	# 长度
	d.tile_size = int(round(float(d.tile_size) * k))
	d.player_size = int(round(float(d.player_size) * k))
	d.attract_radius *= k
	# 速度 / 加速度
	d.gravity *= k
	d.max_fall_speed *= k
	d.move_speed *= k
	d.accel *= k
	d.friction *= k
	d.jump_velocity *= k
	d.projectile_speed *= k
	d.attract_speed *= k
	d.enemy_speed *= k
	d.enemy_attract_speed *= k
	d.flyer_speed *= k
	d.stomp_bounce *= k
	d.boss_shot_speed *= k
	# 世界空间里的字号（在 Assets 里缩放；HUD 字号不受相机影响，不缩放）


## 相机缩放：把世界拉回原来的可见范围
func camera_zoom() -> float:
	return 1.0 / px if px > 0.0 else 1.0
