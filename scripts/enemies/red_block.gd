class_name RedBlock
extends CharacterBody2D
## 红色方块怪（普通怪）。触碰主角扣血，被打死掉金币。
## 若主角带了「慕」（磁吸），它们会被慢慢牵向主角 —— 这是慕的副作用。

var b: BalanceData
var hp: float = 2.0
var contact_damage: float = 1.0
var speed: float = 68.0
var dir: int = -1

var _dead := false
var _flash := 0.0
var _cd := 0.0
var _player: Node2D
var _touch: Area2D
var _ledge: RayCast2D
var _half := 18.0


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	b = balance
	hp = balance.enemy_hp * hp_mul
	contact_damage = balance.enemy_damage
	speed = balance.enemy_speed


func _ready() -> void:
	if b == null:
		b = Balance.d
	collision_layer = 4
	collision_mask = 1
	z_index = 2

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_half * 2.0, _half * 2.0)
	cs.shape = rs
	add_child(cs)

	# 接触判定（只测主角层）
	_touch = Area2D.new()
	_touch.collision_layer = 0
	_touch.collision_mask = 2
	var tcs := CollisionShape2D.new()
	var trs := RectangleShape2D.new()
	trs.size = Vector2(_half * 2.0 + 6.0, _half * 2.0 + 6.0)
	tcs.shape = trs
	_touch.add_child(tcs)
	add_child(_touch)

	# 悬崖检测：走到边缘就转身，别掉下去
	_ledge = RayCast2D.new()
	_ledge.target_position = Vector2(0, 40)
	_ledge.position = Vector2(_half + 4.0, 0.0)
	_ledge.enabled = true
	add_child(_ledge)

	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if b == null:
		b = Balance.d
	if not is_on_floor():
		velocity.y = minf(velocity.y + b.gravity * delta, b.max_fall_speed)

	_flash = maxf(_flash - delta, 0.0)
	_cd = maxf(_cd - delta, 0.0)

	var vx := float(dir) * speed
	# 「慕」的副作用：被牵向主角
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player != null and RunState.has_attract():
		var d: float = _player.global_position.x - global_position.x
		if absf(d) < b.attract_radius:
			vx += signf(d) * b.enemy_attract_speed
	velocity.x = vx

	move_and_slide()

	if is_on_wall():
		_flip()
	_ledge.position.x = _half + 4.0
	if is_on_floor() and not _ledge.is_colliding():
		_flip()

	_touch_player()
	queue_redraw()


func _flip() -> void:
	dir = -dir


func _touch_player() -> void:
	if _cd > 0.0:
		return
	for body in _touch.get_overlapping_bodies():
		if body is Player:
			(body as Player).take_damage(contact_damage, "enemy")
			_cd = b.enemy_contact_cooldown
			return


func hit(damage: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= damage
	_flash = 0.14
	if knockback != Vector2.ZERO:
		velocity += Vector2(knockback.x * 0.4, -90.0)
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	# 注意：死亡常常发生在碰撞回调里（被投射物打中），
	# 而此时物理引擎正在刷新查询，不能直接往场景树里加带碰撞体的节点。
	# 所以交给父节点延迟一帧再加。
	var parent := get_parent()
	var n := 1 + int(TerrainGen.rand01(int(global_position.x), int(global_position.y), 7) * 2.0)
	for i in range(n):
		var c := Coin.new()
		c.setup(Assets.cfg.color_coin)
		c.position = position + Vector2(randf_range(-12, 12), randf_range(-16, 4))
		if parent != null and is_instance_valid(parent):
			parent.call_deferred("add_child", c)
	queue_free()


func _draw() -> void:
	var r := Rect2(Vector2(-_half, -_half), Vector2(_half * 2.0, _half * 2.0))
	var col := Assets.cfg.color_enemy
	if _flash > 0.0:
		col = Color.WHITE
	draw_rect(r, col, true)
	draw_rect(r, col.darkened(0.45), false, 3.0)
	# 朝向的眼睛
	var ex := -4.0 * dir
	draw_circle(Vector2(ex - 4.0, -4.0), 2.6, Color.WHITE)
	draw_circle(Vector2(ex + 4.0, -4.0), 2.6, Color.WHITE)
	draw_circle(Vector2(ex - 4.0 + dir * 1.2, -4.0), 1.3, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(ex + 4.0 + dir * 1.2, -4.0), 1.3, Color(0.1, 0.1, 0.1))
