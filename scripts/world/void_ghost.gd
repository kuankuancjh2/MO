class_name VoidGhost
extends Node2D
## 方块消失后留下的一圈虚线方框残影。
## 「空」的视觉符号：虚线正方形 = 已经归零的地方，也是可以重新填上的地方。

const LIFE := 0.55

var _size: int = 48
var _color: Color = Color(1, 1, 1, 0.3)
var _t := 0.0


func setup(size_px: int, c: Color) -> void:
	_size = size_px
	_color = c


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	var s := float(_size)
	var c := Color(_color.r, _color.g, _color.b, _color.a * a)
	var seg := s / 3.0
	for i in range(3):
		var o := i * seg
		draw_line(Vector2(o, 0), Vector2(o + seg * 0.6, 0), c, 2.0)
		draw_line(Vector2(o, s), Vector2(o + seg * 0.6, s), c, 2.0)
		draw_line(Vector2(0, o), Vector2(0, o + seg * 0.6), c, 2.0)
		draw_line(Vector2(s, o), Vector2(s, o + seg * 0.6), c, 2.0)
