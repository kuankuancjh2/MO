class_name EnemyBase
extends CharacterBody2D
## 地面敌人基类。
##
## 与主角的接口（飞怪/偏旁怪用同名方法实现，主角不需要知道具体类型）：
##   try_contact_damage(player)  —— 侧面撞到主角，按内置冷却扣血
##   hit(damage, knockback)      —— 被投射物打中
##   rideable                    —— 站到它头上时是"骑着走"还是照常触发接触效果
##
## ★ 站到怪头上不会杀死它：主角会被带着走（在 Player._apply_ride 里处理）。
##   所以每个敌人都要记录自己这一帧的位移 move_delta。

var b: BalanceData
var hp: float = 2.0
var max_hp: float = 2.0
var contact_damage: float = 1.0
var coin_min: int = 1
var coin_max: int = 3
var gravity_scale: float = 1.0
var rideable := true
var move_delta := Vector2.ZERO

var _dead := false
var _flash := 0.0
var _contact_cd := 0.0
var _half := 18.0
var _prev_pos := Vector2.ZERO
var _art: Texture2D


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	b = balance
	max_hp = balance.enemy_hp * hp_mul
	hp = max_hp
	contact_damage = balance.enemy_damage


func _ready() -> void:
	if b == null:
		b = Balance.d
	# 尺寸从格子推导 —— 过采样改了格子尺寸，这里跟着变
	_half = float(b.tile_size) * 0.375
	collision_layer = 4
	collision_mask = 1
	z_index = 2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_half * 2.0, _half * 2.0)
	cs.shape = rs
	add_child(cs)
	_art = Assets.get_art(art_name())
	_prev_pos = global_position
	_build()


## 子类覆写：美术文件名（assets/art/<name>.png）
func art_name() -> String:
	return "enemy_block"


func _build() -> void:
	pass


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
	_prev_pos = global_position
	ai(delta)
	move_and_slide()
	move_delta = global_position - _prev_pos
	if _flash > 0.0:
		queue_redraw()


func try_contact_damage(p: Player) -> void:
	if _dead or _contact_cd > 0.0:
		return
	_contact_cd = b.enemy_contact_cooldown
	p.take_damage(contact_damage, "enemy")


func hit(damage: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= damage
	_flash = 0.14
	if knockback != Vector2.ZERO:
		velocity += Vector2(knockback.x * 0.4, -90.0 * Balance.px)
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_mark_consumed()
	_drop_coins()
	queue_free()


func _mark_consumed() -> void:
	var w := get_parent()
	if w != null and w.has_method("consume_cell"):
		w.consume_cell(self)


## 死亡常常发生在碰撞回调里，此时不能直接往场景树加带碰撞体的节点 → 延迟一帧
func _drop_coins() -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var n := randi_range(coin_min, coin_max)
	for i in range(n):
		var c := Coin.new()
		c.setup(Assets.cfg.color_coin)
		c.position = position + Vector2(randf_range(-12, 12), randf_range(-16, 4)) * Balance.px
		parent.call_deferred("add_child", c)


func sprite_color() -> Color:
	if _flash > 0.0:
		return Color.WHITE
	return Assets.cfg.color_enemy


## 有美术图就画图，返回 true 表示已经画完了
func draw_art_if_any() -> bool:
	if _art == null:
		return false
	var sz := _art.get_size()
	draw_texture_rect(_art, Rect2(-sz * 0.5, sz), false,
		Color(1, 1, 1, 1) if _flash <= 0.0 else Color(2, 2, 2, 1))
	return true
