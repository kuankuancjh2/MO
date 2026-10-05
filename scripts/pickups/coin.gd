class_name Coin
extends Area2D
## 金币。带了「慕」的话会被磁吸飞向主角。

var color := Color("#ffd23b")
var _player: Node2D
var _life := 30.0


func setup(c: Color) -> void:
	color = c


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	z_index = 4
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if RunState.has_attract():
		var d := _player.global_position - global_position
		if d.length() < Balance.d.attract_radius:
			global_position += d.normalized() * Balance.d.attract_speed * delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		RunState.add_coins(1)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, color)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 18, color.darkened(0.35), 2.0)
	draw_circle(Vector2(-2.0, -2.0), 3.0, Color(1, 1, 1, 0.55))
