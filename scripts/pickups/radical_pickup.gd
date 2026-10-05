class_name RadicalPickup
extends Area2D
## 从碎掉的方块里浮出来的偏旁。
##
## 视觉：**只有一个偏旁字**（白字黑描边，像写在纸上），没有光球、没有圈 ——
## 保持"世界是黑白书写"的审美统一。
##
## 行为：先向上飘一下（"浮出"的观感），然后自己飞向主角 —— 所以永远不会白捡不到。

const FLOAT_TIME := 0.35     ## 先飘一下多久
const LIFE := 12.0           ## 太久够不到就自己消失（比如主角已经死了）
const SPEED := 260.0

var data: RadicalData
var _t := 0.0
var _life := LIFE
var _taken := false
var _player: Node2D
var _home := false


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
	c.radius = float(Balance.d.tile_size) * 0.458
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")


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
		position.y -= 60.0 * Balance.px * delta          # 先浮出
	else:
		_home = true
		var d := _player.global_position - global_position
		var sp := SPEED * Balance.px
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
	var f := Assets.font
	if f == null or data == null:
		return
	var ch: String = data.radical_char
	var fs := Assets.cfg.radical_font_size
	var sz := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := Vector2(-sz.x * 0.5, sz.y * 0.5 - Balance.px * 5.0)
	var wob := sin(_t * 7.0) * Balance.px * 1.5
	# 纸上墨字：黑字（地图是黑白线稿，偏旁也保持黑白）
	draw_string(f, at + Vector2(0, wob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(0.10, 0.10, 0.10))
