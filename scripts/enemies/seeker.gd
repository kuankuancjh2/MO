class_name Seeker
extends EnemyBase
## 猎手：会追着玩家跑。撞墙且在地面时会跳一下，也会为了追人走下悬崖。
## 因为站到它头上就能骑着走，所以它追过来时"迎上去"也是一种玩法。

var speed: float = 62.0
var jump_velocity: float = -330.0

var _dir: int = -1
var _target: Node2D
var _jump_cd := 0.0
var _search := 0.0
var _was_on_wall := false


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	super.setup(balance, hp_mul)
	speed = balance.enemy_speed * 0.95
	jump_velocity = -330.0 * Balance.px


func art_name() -> String:
	return "enemy_seeker"


func ai(delta: float) -> void:
	_jump_cd = maxf(_jump_cd - delta, 0.0)
	_search -= delta
	if _search <= 0.0:
		_search = 0.5
		_target = get_tree().get_first_node_in_group("player") as Node2D

	var dx := 0.0
	if _target != null and is_instance_valid(_target):
		dx = _target.global_position.x - global_position.x
		if absf(dx) > 4.0:
			_dir = 1 if dx > 0.0 else -1
	velocity.x = float(_dir) * speed

	if is_on_floor() and is_on_wall() and _jump_cd <= 0.0:
		velocity.y = jump_velocity
		_jump_cd = 0.7
	queue_redraw()


func _draw() -> void:
	if draw_art_if_any():
		return
	var c := sprite_color()
	var pts := PackedVector2Array([
		Vector2(-_half, _half), Vector2(_half, _half), Vector2(0.0, -_half),
	])
	draw_colored_polygon(pts, c)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), c.darkened(0.45), 3.0)
	var ex := 3.0 * _dir
	draw_circle(Vector2(ex, 0.0), 3.0, Color.WHITE)
	draw_circle(Vector2(ex + _dir * 1.2, 0.0), 1.5, Color(0.1, 0.1, 0.1))
