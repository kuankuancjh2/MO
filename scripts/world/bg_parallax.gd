class_name BgParallax
extends Node2D
## 视差背景：把素材里那些**没有黑描边的灰剪影**（云、大树、小树）铺成 4 层。
##
## 参考图里地图"有世界感"的关键之一就是背景——不然岛只是浮在虚空里。
## 实现：整层只有一个节点，在 _draw 里按相机位置取模平铺，无限延伸、零成本。
##
## 视差公式：屏幕位置 = 图层坐标 - 相机坐标 × p
##   （p 越小动得越慢，看起来越远）

const LAYERS := [
	{"tex": "background_cloudA", "p": 0.08, "py": 0.05, "step": 900.0, "y": -420.0, "a": 0.20},
	{"tex": "background_cloudB", "p": 0.13, "py": 0.08, "step": 1180.0, "y": 160.0, "a": 0.16},
	{"tex": "background_treeLarge", "p": 0.30, "py": 0.20, "step": 640.0, "y": 430.0, "a": 0.22},
	{"tex": "background_tree", "p": 0.52, "py": 0.34, "step": 470.0, "y": 660.0, "a": 0.30},
]

var _art_cache: Dictionary = {}


func _ready() -> void:
	z_index = -200


func _process(_delta: float) -> void:
	queue_redraw()


func _art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var t := Assets.get_art(name)
	_art_cache[name] = t
	return t


func _draw() -> void:
	var vp := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := vp / cam.zoom
	var cam_c := cam.get_screen_center_position()
	var gap := float(Balance.d.tile_size) * 0.35

	for L in LAYERS:
		var tex := _art(String(L["tex"]))
		if tex == null:
			continue
		var p: float = L["p"]
		var py: float = L["py"]
		var step: float = L["step"]
		var base := cam_c * Vector2(1.0 - p, 1.0 - py)
		var half := view * 0.5
		var i0 := floori((cam_c.x * p - half.x) / step)
		var i1 := ceili((cam_c.x * p + half.x) / step)
		var j0 := floori((cam_c.y * py - half.y) / (step * 1.7))
		var j1 := ceili((cam_c.y * py + half.y) / (step * 1.7))
		var size := tex.get_size()
		var col := Color(1, 1, 1, float(L["a"]))
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var h := TerrainGen.rand01(i * 31 + 7, j * 17 + 3, 991)
				if h > 0.55:
					continue                      # 稀疏一点，别铺满
				var s := 0.8 + h * 0.9
				var at := Vector2(float(i) * step + base.x + h * step * 0.5,
					float(j) * step * 1.7 + base.y + h * gap * 3.0)
				var sz := size * s
				draw_texture_rect(tex, Rect2(at - Vector2(sz.x * 0.5, sz.y * 0.5), sz),
					false, col)
