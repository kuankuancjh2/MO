class_name EnemyBase
extends CharacterBody2D
## 地面敌人基类。
##
## 与主角的接口（飞怪也用同名方法实现，主角不需要知道具体类型）：
##   try_contact_damage(player)  —— 侧面撞到主角，按内置冷却扣血
##   on_stomped(player)          —— 被主角从上方踩到
##   hit(damage, knockback)      —— 被投射物打中
##
## 子类只需要覆写 _build() 和 ai(delta)。

var b: BalanceData
var hp: float = 2.0
var max_hp: float = 2.0
var contact_damage: float = 1.0
var coin_min: int = 1
var coin_max: int = 3
var gravity_scale: float = 1.0

var _dead := false
var _flash := 0.0
var _contact_cd := 0.0
var _half := 18.0


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	b = balance
	max_hp = balance.enemy_hp * hp_mul
	hp = max_hp
	contact_damage = balance.enemy_damage


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
	_build()


## 子类覆写：加自己的视觉 / 额外节点
func _build() -> void:
	pass


## 子类覆写：设置 velocity
func ai(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if b == null:
		b = Balance.d
	_flash = maxf(_flash - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if not is_on_floor():
		velocity.y = minf(velocity.y + b.gravity * gravity_scale * delta, b.max_fall_speed)
	ai(delta)
	move_and_slide()
	if _flash > 0.0:
		queue_redraw()


func try_contact_damage(p: Player) -> void:
	if _dead or _contact_cd > 0.0:
		return
	_contact_cd = b.enemy_contact_cooldown
	p.take_damage(contact_damage, "enemy")


## 被踩头：默认直接死掉，主角弹起
func on_stomped(p: Player) -> void:
	if _dead:
		return
	Sfx.play("stomp")
	p.bounce()
	hit(max_hp + 1.0)


func hit(damage: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= damage
	_flash = 0.14
	if knockback != Vector2.ZERO:
		velocity += Vector2(knockback.x * 0.4, -90.0)
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_drop_coins()
	queue_free()


## 注意：死亡常常发生在碰撞回调里，此时不能直接往场景树加带碰撞体的节点，
## 所以交给父节点延迟一帧再加。
func _drop_coins() -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var n := randi_range(coin_min, coin_max)
	for i in range(n):
		var c := Coin.new()
		c.setup(Assets.cfg.color_coin)
		c.position = position + Vector2(randf_range(-12, 12), randf_range(-16, 4))
		parent.call_deferred("add_child", c)


func sprite_color() -> Color:
	if _flash > 0.0:
		return Color.WHITE
	return Assets.cfg.color_enemy
