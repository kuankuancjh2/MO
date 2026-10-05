class_name Shop
extends Area2D
## 商店：地形里的一个结构（带顶棚的小摊）。走近按 F 打开。
## 价格与效果见 BalanceData 的 shop_* 字段。

const RANGE_NOTE := "按 F 交易"

var player: Node2D
var _t := 0.0
var _near := false
var _main: Node


func setup(p: Node2D) -> void:
	player = p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	z_index = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 46.0
	cs.shape = c
	add_child(cs)
	_main = get_tree().get_first_node_in_group("main")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if body is Player:
		_near = true
		if _main != null and _main.has_method("set_prompt"):
			_main.set_prompt(RANGE_NOTE)


func _on_exit(body: Node2D) -> void:
	if body is Player:
		_near = false
		if _main != null and _main.has_method("set_prompt"):
			_main.set_prompt("")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _near and Input.is_action_just_pressed("interact"):
		if _main != null and _main.has_method("open_shop"):
			_main.open_shop()
		_near = false
		if _main != null and _main.has_method("set_prompt"):
			_main.set_prompt("")


func _draw() -> void:
	var gold := Assets.cfg.color_coin
	# 浮动光晕 + 底环
	var bob := sin(_t * 2.0) * 3.0
	draw_circle(Vector2(0, bob), 24.0, Color(gold.r, gold.g, gold.b, 0.12))
	draw_arc(Vector2(0, bob), 20.0, 0.0, TAU, 30, Color(gold.r, gold.g, gold.b, 0.7), 2.5)
	var f := Assets.font
	if f != null:
		var fs := Assets.cfg.radical_font_size
		var sz := f.get_string_size("店", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(-sz.x * 0.5, bob + sz.y * 0.5 - 5.0), "店",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gold)
