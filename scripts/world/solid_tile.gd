class_name SolidTile
extends StaticBody2D
## 一格地形。外观完全由素材决定（自动拼接）：
##   - 岛：地表行用群系的地表砖（草/沙/顶线），内部用填充砖，最底行把地表砖**垂直翻转**当收口
##   - 桥：`tile_bridge`（素材里的薄板就在画布顶部，和 1 格厚的碰撞天然吻合）
##   - 拱腔（`is_arch`）：不画 —— 让地体看起来像有连拱的堤坝（纯视觉，碰撞仍在）
##
## 被莫触碰后进入消失倒计时。**消失用的是黑白语言**：
##   墨色变深 → 越来越快地闪 → 淡出，像墨被一点点抹掉。
##
## ★ 偏旁藏在地表砖里：radical != null 的砖碎掉时会浮出那个字。

enum State { SOLID, COUNTING, GONE }

var cell: Vector2i
var world: Node
var state: State = State.SOLID
var style: int = 0                 ## 0 岩石 / 1 木板（桥）
var radical: RadicalData = null
var art_name: String = ""
var is_arch: bool = false
var is_bottom: bool = false
var biome: int = 0
var total: float = 4.0
var time_left: float = 0.0

var _size: int = 48
var _art: Texture2D
var _gray: float = 1.0


func setup(c: Vector2i, tile_size: int, w: Node, p_style: int = 0,
		p_radical: RadicalData = null, p_art: String = "",
		p_arch: bool = false, p_bottom: bool = false, p_biome: int = 0) -> void:
	cell = c
	_size = tile_size
	world = w
	style = p_style
	radical = p_radical
	art_name = p_art
	is_arch = p_arch
	is_bottom = p_bottom
	biome = p_biome
	position = Vector2(c.x * tile_size, c.y * tile_size)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = -2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	if style == 1:
		var h := float(_size) * 0.29
		rs.size = Vector2(_size, h)
		cs.position = Vector2(_size * 0.5, h * 0.5)
	else:
		rs.size = Vector2(_size, _size)
		cs.position = Vector2(_size, _size) * 0.5
	cs.shape = rs
	add_child(cs)
	_art = Assets.get_art(art_name) if art_name != "" else null
	_gray = BiomeTable.gray(biome)
	# 性能：几百块砖不该每帧都跑 _process —— 被碰到时才开
	set_process(false)


func on_touched(p: Node) -> void:
	if state != State.SOLID:
		return
	state = State.COUNTING
	var factor := 1.0
	if p != null and "vanish_factor" in p:
		factor = p.vanish_factor
	total = maxf(Balance.d.vanish_time * factor, 0.25)
	time_left = total
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if state != State.COUNTING:
		return
	time_left -= delta
	if time_left <= 0.0:
		_vanish()
		return
	queue_redraw()


func _vanish() -> void:
	state = State.GONE
	Sfx.play_varied("vanish")
	if world != null and world.has_method("notify_destroyed"):
		world.notify_destroyed(cell)
	if radical != null:
		var pick := RadicalPickup.new()
		pick.setup(radical, position + Vector2(_size, _size) * 0.5)
		if world != null:
			world.add_child(pick)
		Sfx.play("shatter")
	if world != null:
		var burst := ShardBurst.new()
		burst.setup(position + Vector2(_size, _size) * 0.5, Color(0.12, 0.12, 0.12),
			9, float(_size) * 0.0625, float(_size) * 2.6)
		world.add_child(burst)
	queue_free()


func _draw() -> void:
	if is_arch:
		return                     # 拱腔：这里不画，露出背后的虚空（视觉上的连拱）
	var s := Vector2(_size, _size)
	var tint := Color(_gray, _gray, _gray, 1.0)
	var alpha := 1.0
	var scale := 1.0

	if state == State.COUNTING:
		var prog := clampf(1.0 - time_left / maxf(total, 0.001), 0.0, 1.0)
		var wr: float = Balance.d.vanish_warn_ratio
		var br: float = Balance.d.vanish_blink_ratio
		if prog < wr:
			# 第一段：墨色变深（"正在被抹掉"）
			var g := lerpf(_gray, 0.55, prog / maxf(wr, 0.001))
			tint = Color(g, g, g, 1.0)
		elif prog < wr + br:
			# 第二段：闪得越来越快（黑白语言：在深灰与近黑之间闪）
			var bp := (prog - wr) / maxf(br, 0.001)
			var freq := 8.0 + bp * 16.0
			var blink := fmod(Time.get_ticks_msec() * 0.001 * freq, 1.0)
			var g2 := 0.42 if blink > 0.5 else 0.10
			tint = Color(g2, g2, g2, 1.0)
		else:
			# 第三段：淡出
			var dp := (prog - wr - br) / maxf(1.0 - wr - br, 0.001)
			tint = Color(0.08, 0.08, 0.08, 1.0)
			alpha = 1.0 - dp
			scale = 1.0 - dp * 0.35

	tint.a = alpha
	if is_bottom:
		# 岛底：把地表砖垂直翻过来当收口
		draw_set_transform(Vector2(0, _size), 0.0, Vector2(1, -1))
		_draw_one(s, tint, scale)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_one(s, tint, scale)

	# 藏了偏旁的砖：砖面上一个小黑点作为提示（黑白语言，不用彩色光晕）
	# 带「谟」时点更大更实 —— 那是它的被动：让你看得见藏起来的字
	if radical != null and state == State.SOLID and not is_arch:
		var reveal := RunState.has_radical_id("mo_yan")
		var r := float(_size) * (0.055 if not reveal else 0.085)
		draw_circle(s * 0.5, r, Color(0, 0, 0, 0.85 if not reveal else 1.0))


func _draw_one(s: Vector2, tint: Color, scale: float) -> void:
	draw_set_transform(s * 0.5, 0.0, Vector2(scale, scale))
	var r := Rect2(-s * 0.5, s)
	if _art != null:
		draw_texture_rect(_art, r, false, tint)
	else:
		draw_rect(r, tint, true)
		draw_rect(r, Color(0, 0, 0, tint.a), false, Balance.px * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
