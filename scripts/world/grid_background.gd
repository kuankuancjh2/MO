class_name GridBackground
extends Node2D
## 无限延伸的虚线方格背景。
## 「空」是虚线的 —— 所以整个世界的地基就是一张虚线方格纸。

var tile: int = 48
var color: Color = Color(1, 1, 1, 0.055)


func _ready() -> void:
	tile = Balance.d.tile_size
	color = Assets.cfg.color_grid
	z_index = -100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var size := vp
	var origin := Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		size = vp / cam.zoom
		origin = cam.get_screen_center_position() - size * 0.5

	var x0 := floori(origin.x / tile)
	var x1 := ceili((origin.x + size.x) / tile)
	var y0 := floori(origin.y / tile)
	var y1 := ceili((origin.y + size.y) / tile)

	var dash := 6.0
	for x in range(x0, x1 + 1):
		var px := float(x * tile)
		draw_dashed_line(Vector2(px, origin.y), Vector2(px, origin.y + size.y), color, 1.0, dash)
	for y in range(y0, y1 + 1):
		var py := float(y * tile)
		draw_dashed_line(Vector2(origin.x, py), Vector2(origin.x + size.x, py), color, 1.0, dash)
