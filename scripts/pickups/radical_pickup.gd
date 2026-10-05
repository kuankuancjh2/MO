class_name RadicalPickup
extends Area2D
## 从碎掉的方块里浮出来的偏旁。
## 刚露出时先向上飘一下（"浮出"的观感），然后自己飞向主角 —— 所以永远不会白捡不到。
##
## 如果主角有「慕」（磁吸），吸得更快。

const FLOAT_TIME := 0.35     ## 先飘一下多久
const LIFE := 12.0           ## 太久够不到就自己消失（比如主角已经死了）
const SPEED := 260.0

var data: RadicalData
var _t := 0.0
var _life := LIFE
var _taken := false
var _player: Node2D
var _home := false
var _art: Texture2D


func setup(d: RadicalData, center: Vector2) -> void:
	data = d
	position = center


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	z_index = 6
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 22.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")
	if data != null:
		_art = Assets.get_art("radical_%s" % data.id)
	if _art == null:
		_art = Assets.get_art("radical_glow")


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if _t < FLOAT_TIME:
		position.y -= 60.0 * delta          # 先浮出
	else:
		_home = true
		var d := _player.global_position - global_position
		var sp := SPEED
		if RunState.has_attract():
			sp *= 1.8
		global_position += d.normalized() * minf(sp * delta, d.length())
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	_taken = true
	RunState.add_radical(data)
	RadicalEffects.on_pickup(body as Player, data)
	Sfx.play("transform")
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_radical"):
		main.announce_radical(data)
	queue_free()


func _draw() -> void:
	var tint: Color = data.tint if data != null else Assets.cfg.color_radical
	var pulse := 1.0 + sin(_t * 9.0) * 0.08
	if _art != null:
		var sz := _art.get_size() * pulse
		draw_texture_rect(_art, Rect2(-sz * 0.5, sz), false)
	draw_circle(Vector2.ZERO, 17.0 * pulse, Color(tint.r, tint.g, tint.b, 0.18))
	draw_arc(Vector2.ZERO, 15.0 * pulse, 0.0, TAU, 26, Color(tint.r, tint.g, tint.b, 0.8), 2.5)
	var f := Assets.font
	if f != null and data != null:
		var ch: String = data.radical_char
		var fs := Assets.cfg.radical_font_size
		var sz2 := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(-sz2.x * 0.5, sz2.y * 0.5 - 5.0), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)
	if _home and _t < FLOAT_TIME + 0.4:
		# 刚起飞时拖一点尾迹，强调"飞过来"
		draw_line(Vector2(0, 14), Vector2(0, 30), Color(tint.r, tint.g, tint.b, 0.35), 3.0)
