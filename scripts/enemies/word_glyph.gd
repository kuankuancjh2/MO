class_name WordGlyph
extends Node2D
## 敌人的"字"。所有普通敌人都挂一个它 —— 这样地怪和飞怪能共用同一套绘制，
## 不用因为继承关系不同而写两遍。
##
## ★ 只画一个字：没有底盘、没有圈、没有脸。和"书写"的审美统一。

var glyph := "命"
var ink := Color("#b8342f")
var flash := false
var base_font_size := 34


func set_word(g: String, c: Color) -> void:
	glyph = g
	ink = c
	queue_redraw()


func _ready() -> void:
	z_index = 2


func _draw() -> void:
	var f := Assets.font
	if f == null:
		return
	var fs := base_font_size
	var sz := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := Vector2(-sz.x * 0.5, sz.y * 0.5 - Balance.px * 5.0)
	var col := ink
	if flash:
		col = ink.lerp(Color(1, 1, 1, 1), 0.6)
		var wob := sin(Time.get_ticks_msec() * 0.05) * Balance.px * 2.0
		at += Vector2(wob, 0)
	draw_string(f, at, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
