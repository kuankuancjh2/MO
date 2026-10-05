class_name DecoLayer
extends Node2D
## 装饰层：长在地表上的树/灌木/陶罐/柱子/牌子…
##
## ★ 全部是**纯视觉、无碰撞**，而且**一个节点都不额外创建** ——
##   整层只有这一个 Node2D，在 _draw 里按"可见格"把素材画出来。
##   放置是确定性随机（看格坐标），所以镜头来回移动装饰不会跳。
##
## 这一层是"地图信息量"的主要来源：参考图里装饰密度比地形还高。

const MAX_DECO := 900        ## 保险丝：单帧最多画多少个

var world: GameWorld
var _tile: int = 128
var _seed: int = 1
var _art_cache: Dictionary = {}


func setup(w: GameWorld) -> void:
	world = w
	_tile = Balance.d.tile_size
	_seed = w.world_seed
	z_index = -1
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()      # 只画可见范围，成本就是一屏几十次绘制


func _art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var t := Assets.get_art(name)
	_art_cache[name] = t
	return t


func _draw() -> void:
	if world == null:
		return
	var vp := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := vp / cam.zoom
	var cam_c := cam.get_screen_center_position()
	var margin := _tile * 3.0
	var x0 := floori((cam_c.x - view.x * 0.5 - margin) / float(_tile))
	var x1 := ceili((cam_c.x + view.x * 0.5 + margin) / float(_tile))
	var y0 := floori((cam_c.y - view.y * 0.5 - margin) / float(_tile))
	var y1 := ceili((cam_c.y + view.y * 0.5 + margin) / float(_tile))
	var k0 := TerrainGen.fdiv(y0, TerrainGen.BAND_ROWS)
	var k1 := TerrainGen.fdiv(y1, TerrainGen.BAND_ROWS)

	var drawn := 0
	for k in range(k0, k1 + 1):
		for cx in range(x0, x1 + 1):
			if drawn >= MAX_DECO:
				return
			var name := TerrainGen.deco_at(cx, k, _seed)
			if name == "":
				continue
			var surf := TerrainGen.surface_row(cx, k, _seed)
			if not TerrainGen.is_solid(cx, surf, _seed):
				continue
			# 地表被莫抹掉过就不长东西了
			if world.is_destroyed(Vector2i(cx, surf)):
				continue
			var tex := _art(name)
			if tex == null:
				continue
			var size := tex.get_size()
			# 底部对齐：装饰站在地表砖的顶边上
			var pos := Vector2(cx * _tile + _tile * 0.5, surf * _tile)
			var occ := TerrainGen.rand01(cx, k * 31 + 1901, _seed)
			var tint := Color(1, 1, 1, 0.72 + occ * 0.28)
			draw_texture_rect(tex, Rect2(pos - Vector2(size.x * 0.5, size.y), size),
				false, tint)
			drawn += 1
