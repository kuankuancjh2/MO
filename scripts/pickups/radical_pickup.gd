class_name RadicalPickup
extends Area2D
## 地上的偏旁。拾取后「莫 + 偏旁 = 新字」，获得对应能力与副作用。

var data: RadicalData
var _player: Node2D
var _t := 0.0
var _taken := false


func setup(d: RadicalData, p: Node2D) -> void:
	data = d
	_player = p


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	z_index = 3
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 20.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	_taken = true
	RunState.add_radical(data)
	RadicalEffects.on_pickup(body as Player, data)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_radical"):
		main.announce_radical(data)
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 2.4) * 3.0
	var tint: Color = data.tint if data != null else Assets.cfg.color_radical
	# 光晕
	draw_circle(Vector2(0, bob), 22.0, Color(tint.r, tint.g, tint.b, 0.14))
	draw_arc(Vector2(0, bob), 18.0, 0.0, TAU, 28, Color(tint.r, tint.g, tint.b, 0.55), 2.0)
	if data != null:
		var f := Assets.font
		if f != null:
			var ch: String = data.radical_char
			var fs := Assets.cfg.radical_font_size
			var sz := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, Vector2(-sz.x * 0.5, bob + sz.y * 0.5 - 4.0), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)
