class_name RedBlock
extends EnemyBase
## 红色方块怪（巡逻）：遇墙转身，走到悬崖边也转身 —— 不会自己掉下去。
## 你可以跳到它头上骑着它走。

var dir: int = -1
var speed: float = 68.0

var _ledge: RayCast2D


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	super.setup(balance, hp_mul)
	speed = balance.enemy_speed


func art_name() -> String:
	return "enemy_block"


func _build() -> void:
	_ledge = RayCast2D.new()
	# 悬崖预判的射线长度要按格子算 —— 过采样后格子变大了，用旧的 40px 会够不到地面，
	# 结果怪会以为处处是悬崖、原地反复转身（这就是"怪不动"的经典原因）
	_ledge.target_position = Vector2(0, float(Balance.d.tile_size) * 0.95)
	_ledge.position = Vector2(_half + 4.0 * Balance.px, 0.0)
	_ledge.enabled = true
	add_child(_ledge)


func ai(_delta: float) -> void:
	velocity.x = float(dir) * speed
	_ledge.position.x = _half + 4.0 * Balance.px
	if is_on_wall():
		_flip()
	elif is_on_floor() and not _ledge.is_colliding():
		_flip()
	queue_redraw()


func _flip() -> void:
	dir = -dir


func _draw() -> void:
	if draw_art_if_any():
		return
	var c := sprite_color()
	var r := Rect2(Vector2(-_half, -_half), Vector2(_half * 2.0, _half * 2.0))
	draw_rect(r, c, true)
	draw_rect(r, c.darkened(0.45), false, 3.0)
	var ex := -4.0 * dir
	draw_circle(Vector2(ex - 4.0, -4.0), 2.6, Color.WHITE)
	draw_circle(Vector2(ex + 4.0, -4.0), 2.6, Color.WHITE)
	draw_circle(Vector2(ex - 4.0 + dir * 1.2, -4.0), 1.3, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(ex + 4.0 + dir * 1.2, -4.0), 1.3, Color(0.1, 0.1, 0.1))
