class_name SolidTile
extends StaticBody2D
## 可站立的方块。
## 被主角「莫」触碰后进入消失倒计时 —— 这是全作最核心的机制。
##
## 消失过程分三段，必须让玩家能「读」出来还剩多久：
##   1. 变色：普通色 -> 被踩色（渐变）
##   2. 闪烁：越来越快，颜色偏向危险红
##   3. 消散：整块缩小 + 淡出，留下一圈虚线方框的残影
##
## 换外观：AssetConfig 里给了贴图就画贴图，否则程序画方框。

enum State { SOLID, COUNTING, GONE }

var cell: Vector2i
var world: Node
var state: State = State.SOLID
var total: float = 4.0
var time_left: float = 0.0

var _size: int = 48
var _shape: CollisionShape2D
var _fill: Color
var _border: Color
var _stepped: Color
var _warn: Color
var _tex: Texture2D
var _stepped_tex: Texture2D


func setup(c: Vector2i, tile_size: int, w: Node) -> void:
	cell = c
	_size = tile_size
	world = w
	position = Vector2(c.x * tile_size, c.y * tile_size)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_size, _size)
	cs.shape = rs
	cs.position = Vector2(_size, _size) * 0.5
	add_child(cs)
	_shape = cs

	var cfg := Assets.cfg
	_fill = cfg.color_solid_tile
	_border = cfg.color_solid_border
	_stepped = cfg.color_tile_stepped
	_warn = cfg.color_tile_warn
	_tex = cfg.solid_tile_texture
	_stepped_tex = cfg.stepped_tile_texture
	z_index = -1
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
	total = maxf(Balance.d.vanish_time * factor, 0.30)
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
	_spawn_ghost()
	queue_free()


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
	var tex := _tex

	if state == State.COUNTING:
		var prog := clampf(1.0 - time_left / maxf(total, 0.001), 0.0, 1.0)
		var wr: float = Balance.d.vanish_warn_ratio
		var br: float = Balance.d.vanish_blink_ratio
		if prog < wr:
			# 第一段：渐变到「被踩」色
			var k := prog / maxf(wr, 0.001)
			fill = _fill.lerp(_stepped, k)
			if _stepped_tex != null:
				tex = _tex
		elif prog < wr + br:
			# 第二段：闪烁
			var bp := (prog - wr) / maxf(br, 0.001)
			fill = _stepped.lerp(_warn, bp)
			border = _warn
			tex = null
			var freq := 8.0 + bp * 16.0
			var blink := fmod(Time.get_ticks_msec() * 0.001 * freq, 1.0)
			alpha = 0.45 + 0.55 * (1.0 if blink > 0.5 else 0.12)
		else:
			# 第三段：消散
			var dp := (prog - wr - br) / maxf(1.0 - wr - br, 0.001)
			fill = _warn
			border = _warn
			tex = null
			alpha = 1.0 - dp
			scale = 1.0 - dp * 0.40

	draw_set_transform(s * 0.5, 0.0, Vector2(scale, scale))
	var r := Rect2(-s * 0.5, s)
	if tex != null and state == State.SOLID:
		draw_texture_rect(tex, r, false)
	else:
		draw_rect(r, Color(fill.r, fill.g, fill.b, fill.a * alpha), true)
		if tex != null:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, alpha))
	draw_rect(r, Color(border.r, border.g, border.b, border.a * alpha), false, 2.0)
