class_name DecoLayer
extends Node2D
## 装饰层：地表上的树/灌木/陶罐/柱子/牌子，桥下的拱撑，结构里的拱门/梯子/栅栏…
##
## ★ 全部是**纯视觉、无碰撞**，而且**一个节点都不额外创建** —— 整层只有一个 Node2D。
##   放置是确定性随机（看格坐标），所以镜头来回移动装饰不会跳。
##
## ★ 全部按素材的「内容包围盒」对齐（底部居中），否则会因为透明留白而"浮"在地上。

const MAX_DECO := 1200

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
	queue_redraw()


func _art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var t := Assets.get_art(name)
	_art_cache[name] = t
	return t


func _blit(name: String, at: Vector2, tint: Color, scale: float = 1.0) -> bool:
	var tex := _art(name)
	if tex == null:
		return false
	draw_texture_rect(tex, Assets.art_rect_bottom_center(name, at, scale), false, tint)
	return true


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

	_bridge_supports(x0, x1, k0, k1)
	_draw_deco(x0, x1, k0, k1)
	_draw_structure_markers(x0, x1, y0, y1, k0, k1)


## 桥下的拱撑：桥面下方画 bridge_arch，缺口两端画桥墩
func _bridge_supports(x0: int, x1: int, k0: int, k1: int) -> void:
	var s := _seed
	for k in range(k0, k1 + 1):
		for cx in range(x0, x1 + 1):
			if TerrainGen.kind_at(cx, k, s) != 2:
				continue
			var row := TerrainGen.surface_row(cx, k, s)
			var under := Vector2(cx * _tile + _tile * 0.5, (row + 2) * _tile)
			# 拱撑：只在下面是空的时画（免得插进地体）
			if not TerrainGen.is_solid(cx, row + 1, s):
				_blit("bridge_arch", under, Color(1, 1, 1, 0.92))
			# 缺口两端 -> 桥墩
			var first := TerrainGen.kind_at(cx - 1, k, s) != 2
			var last := TerrainGen.kind_at(cx + 1, k, s) != 2
			if first or last:
				_blit("bridge_column", Vector2(cx * _tile + _tile * 0.5, (row + 3) * _tile),
					Color(1, 1, 1, 0.95))


## 地表装饰：按群系长树/灌木/陶罐/柱子…
func _draw_deco(x0: int, x1: int, k0: int, k1: int) -> void:
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
			if world.is_destroyed(Vector2i(cx, surf)):
				continue
			var occ := TerrainGen.rand01(cx, k * 31 + 1901, _seed)
			var tint := Color(1, 1, 1, 0.72 + occ * 0.28)
			var at := Vector2(cx * _tile + _tile * 0.5, surf * _tile)
			if _blit(name, at, tint, 0.9 + occ * 0.25):
				drawn += 1


## 结构里的拱门/梯子/栅栏…（非实心，但要画出来）
func _draw_structure_markers(x0: int, x1: int, y0: int, y1: int, k0: int, k1: int) -> void:
	var si0 := TerrainGen.fdiv(x0 - TerrainGen.STRUCT_MARGIN, TerrainGen.STRUCT_SPAN)
	var si1 := TerrainGen.fdiv(x1 - TerrainGen.STRUCT_MARGIN, TerrainGen.STRUCT_SPAN)
	for k in range(k0, k1 + 1):
		for si in range(si0, si1 + 2):
			var st := TerrainGen.struct_for_slot(si, k, _seed)
			if st == null:
				continue
			var ox := TerrainGen.struct_anchor_col(si, k, st.width(), _seed)
			if ox < 0:
				continue
			var base := TerrainGen.struct_base_row(si, k, _seed)
			for gr in range(st.height()):
				var line: String = st.grid[gr]
				for col in range(line.length()):
					var name := TerrainGen.marker_art(line[col])
					if name == "":
						continue
					var wx := ox + col
					var wy := base + gr - st.height()
					if wx < x0 or wx > x1 or wy < y0 or wy > y1:
						continue
					_blit(name, Vector2(wx * _tile + _tile * 0.5, (wy + 1) * _tile),
						Color(1, 1, 1, 1))
