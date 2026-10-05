class_name Flyer
extends AnimatableBody2D
## 飞怪。
##
## 两个身份：
##   1. 平时：无重力飞行，平滑地追向玩家（比方块怪聪明）。
##   2. **被踩到头顶时不死**，而是被驯服 6 秒 —— 这时它是一块会飞的移动平台，
##      玩家站在上面会被带着走（按住跳跃还能让它上升）。可以用它跨越长坑。
##
## 为什么用 AnimatableBody2D：它是「移动平台」。
## collision_layer 含 layer 1，而 CharacterBody2D.platform_floor_layers 默认就是 layer 1，
## 所以玩家站上去会自动被带着走，不需要手写"跟随"逻辑。
##
## 与主角的接口与 EnemyBase 同名（try_contact_damage / on_stomped / hit），
## 所以主角不需要知道它是飞怪还是地怪。

var b: BalanceData
var hp: float = 2.0
var max_hp: float = 2.0
var contact_damage: float = 1.0
var coin_min: int = 1
var coin_max: int = 2

var tamed := false

var _speed := 82.0
var _tame_left := 0.0
var _tame_dir := 1
var _flash := 0.0
var _contact_cd := 0.0
var _dead := false
var _t := 0.0
var _target: Node2D
var _search := 0.0
var _half := 17.0
var _vel := Vector2.ZERO


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	b = balance
	max_hp = balance.enemy_hp * hp_mul
	hp = max_hp
	contact_damage = balance.enemy_damage
	_speed = balance.flyer_speed


func _ready() -> void:
	if b == null:
		b = Balance.d
	# layer 1 = 玩家会把「站上去的东西」当地板并接受其速度；layer 4 = 可被墨点打中
	collision_layer = 1 | 4
	collision_mask = 0          # 穿墙飞
	sync_to_physics = true
	z_index = 3
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_half * 2.0, _half * 1.4)
	cs.shape = rs
	add_child(cs)
	_search = randf() * 0.4


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if b == null:
		b = Balance.d
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)

	if tamed:
		_tame_left -= delta
		# 被驯服：水平朝一个方向飞；骑手按住跳跃可以拉升
		var vy := 0.0
		if Input.is_action_pressed("jump"):
			vy = -_speed * 0.9
		else:
			vy = -14.0        # 缓慢上浮，像悬停
		_vel = Vector2(float(_tame_dir) * _speed * 1.25, vy)
		if _tame_left <= 0.0:
			tamed = false
			_flash = 0.2
			Sfx.play("land")
	else:
		_search -= delta
		if _search <= 0.0:
			_search = 0.4
			_target = get_tree().get_first_node_in_group("player") as Node2D
		if _target != null and is_instance_valid(_target):
			var d := _target.global_position - global_position
			# 保持一点距离：飞怪是"移动平台"，贴着玩家会把人顶来顶去
			if d.length() > 62.0:
				_vel = _vel.lerp(d.normalized() * _speed, clampf(delta * 2.2, 0.0, 1.0))
			else:
				_vel = _vel.lerp(Vector2(0.0, -8.0), clampf(delta * 1.5, 0.0, 1.0))
		else:
			_vel = Vector2(float(_tame_dir) * _speed * 0.5, 0.0)

	position += _vel * delta
	position.y += sin(_t * 3.2) * 0.35   # 轻微上下浮动
	queue_redraw()


func try_contact_damage(p: Player) -> void:
	if _dead or tamed:
		return        # 驯服后是自己人，不伤人
	if _contact_cd > 0.0:
		return
	_contact_cd = b.enemy_contact_cooldown
	p.take_damage(contact_damage, "enemy")


## 踩头：不死，被驯服 —— 变成能载人的飞行平台
func on_stomped(p: Player) -> void:
	if _dead:
		return
	tamed = true
	_tame_left = b.flyer_tame_time
	_tame_dir = p.facing
	_flash = 0.2
	Sfx.play("stomp")
	p.bounce(0.6)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_text"):
		main.announce_text("驯服飞怪！站上去，按跳跃可以拉升")


func hit(damage: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= damage
	_flash = 0.14
	if knockback != Vector2.ZERO:
		_vel += knockback * 0.5
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	var w := get_parent()
	if w != null and w.has_method("consume_cell"):
		w.consume_cell(self)
	var parent := w
	if parent != null and is_instance_valid(parent):
		var n := randi_range(coin_min, coin_max)
		for i in range(n):
			var c := Coin.new()
			c.setup(Assets.cfg.color_coin)
			c.position = position + Vector2(randf_range(-12, 12), randf_range(-12, 8))
			parent.call_deferred("add_child", c)
	queue_free()


func _draw() -> void:
	var c := Assets.cfg.color_enemy
	if _flash > 0.0:
		c = Color.WHITE
	elif tamed:
		c = Color(0.45, 0.85, 1.0)     # 驯服后变蓝，一眼看出是"自己人/交通工具"
	# 菱形身体 + 两侧翅膀
	var body := PackedVector2Array([
		Vector2(0, -_half * 0.9), Vector2(_half, 0), Vector2(0, _half * 0.9), Vector2(-_half, 0),
	])
	draw_colored_polygon(body, c)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]),
		c.darkened(0.45), 2.0)
	var flap := sin(_t * 14.0) * 4.0
	var wing_l := PackedVector2Array([Vector2(-_half, 0), Vector2(-_half - 12.0, -6.0 + flap), Vector2(-_half - 4.0, 6.0)])
	var wing_r := PackedVector2Array([Vector2(_half, 0), Vector2(_half + 12.0, -6.0 + flap), Vector2(_half + 4.0, 6.0)])
	draw_colored_polygon(wing_l, Color(c.r, c.g, c.b, 0.55))
	draw_colored_polygon(wing_r, Color(c.r, c.g, c.b, 0.55))
	draw_circle(Vector2(-4.0, -2.0), 2.6, Color.WHITE)
	draw_circle(Vector2(4.0, -2.0), 2.6, Color.WHITE)
	draw_circle(Vector2(-4.0, -2.0), 1.3, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(4.0, -2.0), 1.3, Color(0.1, 0.1, 0.1))
