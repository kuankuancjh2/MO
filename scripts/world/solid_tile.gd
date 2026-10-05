class_name SolidTile
extends StaticBody2D
## 可站立的方块。两种外观：
##   style 0 = 岩石（岛体，厚实）
##   style 1 = 木板（桥，薄）
##
## 被主角「莫」触碰后进入消失倒计时 —— 全作最核心的机制。
## 消失过程分三段，必须让玩家能「读」出还剩多久：变色 -> 闪烁 -> 消散。
##
## ★ 偏旁藏在方块里：radical != null 的方块碎掉时，会从碎块里"浮出"那个字，
##   字自己会飞向主角（见 RadicalPickup）—— 打破方块才能露出偏旁。
##
## 换外观：assets/art/tile_rock.png 等（见 docs/美术资源指南.md），
##         或改 assets/config/asset_config.tres 里的贴图/颜色。

enum State { SOLID, COUNTING, GONE }

var cell: Vector2i
var world: Node
var state: State = State.SOLID
var style: int = 0                 ## 0 岩石 / 1 木板
var radical: RadicalData = null    ## 里面藏的偏旁（null = 普通方块）
var total: float = 4.0
var time_left: float = 0.0

var _size: int = 48
var _fill: Color
var _border: Color
var _stepped: Color
var _warn: Color
var _art: Texture2D
var _art_stepped: Texture2D
var _art_bridge: Texture2D


func setup(c: Vector2i, tile_size: int, w: Node, p_style: int = 0,
		p_radical: RadicalData = null) -> void:
	cell = c
	_size = tile_size
	world = w
	style = p_style
	radical = p_radical
	position = Vector2(c.x * tile_size, c.y * tile_size)


func _is_bridge() -> bool:
	return style == 1


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = -1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	if _is_bridge():
		var h := float(_size) * 0.29
		rs.size = Vector2(_size, h)
		cs.position = Vector2(_size * 0.5, h * 0.5)
	else:
		rs.size = Vector2(_size, _size)
		cs.position = Vector2(_size, _size) * 0.5
	cs.shape = rs
	add_child(cs)

	var cfg := Assets.cfg
	_fill = cfg.color_solid_tile
	_border = cfg.color_solid_border
	_stepped = cfg.color_tile_stepped
	_warn = cfg.color_tile_warn
	_art = Assets.get_art("tile_rock")
	_art_stepped = Assets.get_art("tile_rock_stepped")
	_art_bridge = Assets.get_art("tile_bridge")
	# 性能：几百块砖不该每帧都跑 _process —— 被碰到时才开
	set_process(false)


## 被主角触碰：开始倒计时。
## p.vanish_factor 来自携带的偏旁（例如「暮」会让消失变慢）。
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
	# ★ 方块碎了 —— 把里面的偏旁露出来
	if radical != null:
		var pick := RadicalPickup.new()
		pick.setup(radical, _cell_center())
		if world != null:
			world.add_child(pick)
		Sfx.play("shatter")
	_spawn_ghost()
	queue_free()


func _cell_center() -> Vector2:
	return position + Vector2(_size, _size) * 0.5


func _spawn_ghost() -> void:
	var ghost := VoidGhost.new()
	ghost.setup(_size, Assets.cfg.color_void_ghost)
	ghost.position = position
	get_parent().add_child(ghost)


func _draw() -> void:
	var s := Vector2(_size, _size)
	var fill := _fill
	var border := _border
	var alpha := 1.0
	var scale := 1.0
	var art: Texture2D = _art

	if state == State.COUNTING:
		var prog := clampf(1.0 - time_left / maxf(total, 0.001), 0.0, 1.0)
		var wr: float = Balance.d.vanish_warn_ratio
		var br: float = Balance.d.vanish_blink_ratio
		if prog < wr:
			fill = _fill.lerp(_stepped, prog / maxf(wr, 0.001))
			if style == 1:
				art = _art_bridge
			elif _art_stepped != null:
				art = _art_stepped
		elif prog < wr + br:
			var bp := (prog - wr) / maxf(br, 0.001)
			fill = _stepped.lerp(_warn, bp)
			border = _warn
			art = null
			var freq := 8.0 + bp * 16.0
			var blink := fmod(Time.get_ticks_msec() * 0.001 * freq, 1.0)
			alpha = 0.45 + 0.55 * (1.0 if blink > 0.5 else 0.12)
		else:
			var dp := (prog - wr - br) / maxf(1.0 - wr - br, 0.001)
			fill = _warn
			border = _warn
			art = null
			alpha = 1.0 - dp
			scale = 1.0 - dp * 0.40

	if _is_bridge():
		_draw_bridge(s, fill, border, alpha, scale, art)
		return

	draw_set_transform(s * 0.5, 0.0, Vector2(scale, scale))
	var r := Rect2(-s * 0.5, s)
	if art != null:
		draw_texture_rect(art, r, false, Color(1, 1, 1, alpha))
	else:
		draw_rect(r, Color(fill.r, fill.g, fill.b, fill.a * alpha), true)
	# 藏了偏旁的砖给一点微光，作为「这里可能有东西」的提示
	# （带「谟」的话光更明显 —— 那是它的被动：让你看得见藏起来的字）
	if radical != null and state == State.SOLID:
		var t := radical.tint
		var reveal := RunState.has_radical_id("mo_yan")
		var glow := 0.85 if reveal else 0.45
		draw_circle(Vector2.ZERO, 5.0 if not reveal else 6.5, Color(t.r, t.g, t.b, glow))
		draw_arc(Vector2.ZERO, 11.0 if not reveal else 15.0, 0.0, TAU, 20,
			Color(t.r, t.g, t.b, 0.5 if not reveal else 0.9), 2.0)
	draw_rect(r, Color(border.r, border.g, border.b, border.a * alpha), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 桥：一块薄木板 + 两端的吊索，一眼看出是"连接器"而不是岛
func _draw_bridge(s: Vector2, fill: Color, border: Color, alpha: float,
		scale: float, art: Texture2D) -> void:
	draw_set_transform(Vector2(s.x * 0.5, float(_size) * 0.145), 0.0, Vector2(scale, scale))
	var bh := float(_size) * 0.29
	var plank := Rect2(-s.x * 0.5, -bh * 0.5, s.x, bh)
	if art != null:
		draw_texture_rect(art, plank, false, Color(1, 1, 1, alpha))
	else:
		var wood := fill.lerp(Color(0.55, 0.42, 0.28), 0.55)
		draw_rect(plank, Color(wood.r, wood.g, wood.b, alpha), true)
		draw_rect(plank, Color(border.r, border.g, border.b, 0.8 * alpha), false, 2.0)
		# 木板纹路
		for i in range(3):
			var x := -s.x * 0.5 + s.x * (float(i) + 0.5) / 3.0
			draw_line(Vector2(x, -5.0), Vector2(x, 5.0), Color(0, 0, 0, 0.25 * alpha), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
