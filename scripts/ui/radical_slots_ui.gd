class_name RadicalSlotsUI
extends Control
## 偏旁 UI：屏幕左下角一排「字砖」，和世界里的字块同一种视觉语言。
## 空槽位画成虚线方块 —— 和「空」的主题一致。
## 每块砖下面写它当前的效果与代价。

const BLOCK := 34.0
const GAP := 7.0

var player: Player


func setup(p: Player) -> void:
	player = p
	RunState.radicals_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()   # 影子/闪烁很便宜，且能跟着视野变化刷新


func _draw() -> void:
	var cfg := Assets.cfg
	var f := Assets.font
	var line_h := 18.0
	var y := 0.0

	# 标题
	if f != null:
		draw_string(f, Vector2(0, 12), "字", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(cfg.hud_font_size * 0.8), cfg.color_hud_dim)

	# 一个字的砖（黑白：白砖 + 黑边 + 黑字），右边一条剩余时间
	var r := Rect2(BLOCK + GAP, -BLOCK * 0.5, BLOCK, BLOCK)
	var d: RadicalData = RunState.current()
	if d != null:
		draw_rect(r, Color(1, 1, 1, 0.95), true)
		draw_rect(r, Color(0.10, 0.10, 0.10, 0.95), false, 2.0)
		if f != null:
			var ch: String = d.composed_char
			var fs := int(cfg.hud_font_size)
			var sz := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, Vector2(r.position.x + BLOCK * 0.5 - sz.x * 0.5,
				sz.y * 0.5 - 5.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(0.10, 0.10, 0.10))
		# 剩余时间条：字是临时的，要能一眼看出还剩多久
		var frac := clampf(RunState.radical_left / RunState.RADICAL_TIME, 0.0, 1.0)
		var bar := Rect2(r.position.x, r.end.y + 5.0, BLOCK, 5.0)
		draw_rect(bar, Color(0.10, 0.10, 0.10, 0.18), true)
		draw_rect(Rect2(bar.position, Vector2(BLOCK * frac, 5.0)),
			Color(0.10, 0.10, 0.10, 0.85), true)
	else:
		# 空位 = 虚线方块
		_draw_dashed_rect(r, Color(0.10, 0.10, 0.10, 0.22))

	# 说明
	y = BLOCK * 0.5 + line_h + 6.0
	if d != null and f != null:
		draw_string(f, Vector2(0, y), "%s：%s" % [d.composed_char, d.summary()],
			HORIZONTAL_ALIGNMENT_LEFT, 620.0, int(cfg.hud_font_size * 0.68),
			Color(0.16, 0.16, 0.16, 0.9))
	elif f != null:
		draw_string(f, Vector2(0, y), "踩碎地里的字块，把「莫」填成新的字",
			HORIZONTAL_ALIGNMENT_LEFT, 620.0, int(cfg.hud_font_size * 0.68), cfg.color_hud_dim)


func _draw_dashed_rect(r: Rect2, c: Color) -> void:
	var seg := 6.0
	var x := r.position.x
	while x < r.end.x:
		var w := minf(seg * 0.6, r.end.x - x)
		draw_line(Vector2(x, r.position.y), Vector2(x + w, r.position.y), c, 2.0)
		draw_line(Vector2(x, r.end.y), Vector2(x + w, r.end.y), c, 2.0)
		x += seg
	var y := r.position.y
	while y < r.end.y:
		var h := minf(seg * 0.6, r.end.y - y)
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y + h), c, 2.0)
		draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y + h), c, 2.0)
		y += seg
