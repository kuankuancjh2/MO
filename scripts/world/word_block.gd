class_name WordBlock
extends StaticBody2D
## 「字块」：一块含字的方砖。莫碰到它就把它撞碎，碎掉的瞬间字归莫所有。
##
## 为什么做成实心方块：撞碎它本身就是通行的一部分 —— 不额外多一个拾取动作，
## 而是「你撞碎字，才能过去」。

enum State { INTACT, CRUMBLING, GONE }

const CRUMBLE_TIME := 0.25

var cell: Vector2i
var data: RadicalData
var world: Node
var state: State = State.INTACT

var _size: int = 48
var _t := 0.0
var _player: Node


func setup(c: Vector2i, tile_size: int, w: Node, d: RadicalData) -> void:
	cell = c
	_size = tile_size
	world = w
	data = d


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_size, _size)
	cs.shape = rs
	cs.position = Vector2(_size, _size) * 0.5
	add_child(cs)
	set_process(false)


## 被莫碰到 —— 开始碎裂
func on_touched(p: Node) -> void:
	if state != State.INTACT:
		return
	state = State.CRUMBLING
	_player = p
	_t = 0.0
	set_process(true)
	Sfx.play_varied("shatter")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= CRUMBLE_TIME:
		_shatter()


func _shatter() -> void:
	state = State.GONE
	if world != null:
		# 记为「永久消失」并注销出生格 —— 否则卸载重载后字块会重新长出来，
		# 玩家就能反复刷同一个字。
		if world.has_method("notify_destroyed"):
			world.notify_destroyed(cell)
		if world.has_method("consume_cell"):
			world.consume_cell(self)
	if data != null:
		RunState.add_radical(data)
		if _player is Player:
			RadicalEffects.on_pickup(_player as Player, data)
		Sfx.play("transform")
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("announce_radical"):
			main.announce_radical(data)
	var parent := get_parent()
	if parent != null:
		var burst := ShardBurst.new()
		burst.setup(position + Vector2(_size, _size) * 0.5,
			data.tint if data != null else Assets.cfg.color_radical, 12, 6.0, 180.0)
		parent.add_child(burst)
	queue_free()


func _draw() -> void:
	var s := Vector2(_size, _size)
	var tint: Color = data.tint if data != null else Assets.cfg.color_radical
	var alpha := 1.0
	var scale := 1.0
	if state == State.CRUMBLING:
		var p := clampf(_t / CRUMBLE_TIME, 0.0, 1.0)
		alpha = 1.0 - p
		scale = 1.0 + p * 0.18
	draw_set_transform(s * 0.5, 0.0, Vector2(scale, scale))
	var r := Rect2(-s * 0.5, s)
	draw_rect(r, Color(0.10, 0.11, 0.14, 0.96 * alpha), true)
	draw_rect(r, Color(tint.r, tint.g, tint.b, 0.85 * alpha), false, 3.0)
	var f := Assets.font
	if f != null and data != null:
		var ch: String = data.composed_char
		var fs := Assets.cfg.radical_font_size
		var sz := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(-sz.x * 0.5, sz.y * 0.5 - 5.0), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tint.r, tint.g, tint.b, alpha))
