class_name RedBlock
extends EnemyBase
## 红色方块怪（巡逻）：遇墙转身，走到悬崖边也转身 —— 不会自己掉下去。

var dir: int = -1
var speed: float = 68.0

var _ledge: RayCast2D


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	super.setup(balance, hp_mul)
	speed = balance.enemy_speed


func _build() -> void:
	_ledge = RayCast2D.new()
	_ledge.target_position = Vector2(0, 40)
	_ledge.position = Vector2(_half + 4.0, 0.0)
	_ledge.enabled = true
	add_child(_ledge)


func ai(_delta: float) -> void:
	velocity.x = float(dir) * speed
	_ledge.position.x = _half + 4.0
	if is_on_wall():
		_flip()
	elif is_on_floor() and not _ledge.is_colliding():
		_flip()
	queue_redraw()


func _flip() -> void:
	dir = -dir


func _draw() -> void:
	var c := sprite_color()
	var r := Rect2(Vector2(-_half, -_half), Vector2(_half * 2.0, _half * 2.0))
	draw_rect(r, c, true)
	draw_rect(r, c.darkened(0.45), false, 3.0)
	var ex := -4.0 * dir
	draw_circle(Vector2(ex - 4.0, -4.0), 2.6, Color.WHITE)
	draw_circle(Vector2(ex + 4.0, -4.0), 2.6, Color.WHITE)
	draw_circle(Vector2(ex - 4.0 + dir * 1.2, -4.0), 1.3, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(ex + 4.0 + dir * 1.2, -4.0), 1.3, Color(0.1, 0.1, 0.1))
