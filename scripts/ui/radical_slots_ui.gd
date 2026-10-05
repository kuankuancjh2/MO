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
	var slots: int = RunState.slot_count
	var y := 0.0

	# 标题
	if f != null:
		draw_string(f, Vector2(0, 12), "字", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(cfg.hud_font_size * 0.8), cfg.color_hud_dim)

	# 一排字砖（黑白：白砖 + 黑边 + 黑字 —— 和地图同一种"纸上的字"语言）
	for i in range(slots):
		var x := (i + 1) * (BLOCK + GAP)
		var r := Rect2(x, -BLOCK * 0.5, BLOCK, BLOCK)
		if i < RunState.radicals.size():
			var d: RadicalData = RunState.radicals[i]
			draw_rect(r, Color(1, 1, 1, 0.95), true)
			draw_rect(r, Color(0.10, 0.10, 0.10, 0.95), false, 2.0)
			if f != null:
				var ch: String = d.composed_char
				var fs := int(cfg.hud_font_size)
				var sz := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				draw_string(f, Vector2(x + BLOCK * 0.5 - sz.x * 0.5,
					sz.y * 0.5 - 5.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					Color(0.10, 0.10, 0.10))
		else:
			# 空槽位 = 虚线方块
			_draw_dashed_rect(r, Color(0.10, 0.10, 0.10, 0.22))

	# 每个字的说明
	y = BLOCK * 0.5 + line_h
	for d in RunState.radicals:
		if f == null:
			break
		var text := "%s：%s" % [d.composed_char, d.summary()]
		draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_LEFT, 560.0,
			int(cfg.hud_font_size * 0.68), Color(0.16, 0.16, 0.16, 0.9))
		y += line_h * 0.86
	if RunState.radicals.is_empty() and f != null:
		draw_string(f, Vector2(0, y), "撞碎地里的字块，把「莫」填成新的字",
			HORIZONTAL_ALIGNMENT_LEFT, 520.0, int(cfg.hud_font_size * 0.68), cfg.color_hud_dim)


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
