class_name Flyer
extends CharacterBody2D
## 飞怪：会飞的敌人，也是**会飞的交通工具**。
##
## 行为：绕着出生点做平滑的正弦飞行（水平往返 + 上下起伏），
## 同时非常缓慢地朝玩家方向挪动，所以玩家等得到它、跳得上去。
## ★ 踩到它头上不会杀死它 —— 你只是**站在它身上被它带着走**，它往哪飞你去哪，
##   你控制不了它（想下来就跳走）。这就是它的全部设计。
##
## 之前用 AnimatableBody2D 有个坑：它继承自 StaticBody2D，且 sync_to_physics 会
## 覆盖直接写入的 position，结果既不飞也不动。改成 CharacterBody2D + move_and_slide 就正常了。

var b: BalanceData
var hp: float = 2.0
var max_hp: float = 2.0
var contact_damage: float = 1.0
var coin_min: int = 1
var coin_max: int = 2
var rideable := true
var move_delta := Vector2.ZERO

var home := Vector2.ZERO
var _speed := 82.0
var _flash := 0.0
var _contact_cd := 0.0
var _dead := false
var _t := 0.0
var _phase := 0.0
var _target: Node2D
var _search := 0.0
var _half := 17.0
var _prev_pos := Vector2.ZERO
var _art: Texture2D
var _wg: WordGlyph
## ★ 这个敌人是哪个"字"
var word_glyph := "名"
var word_name := "名声"
var word_ink := Color("#2f7d86")
var word_speed_mul := 1.0


## 与 EnemyBase 同名的方法（飞怪不继承它，但对外接口保持一致）
func apply_word(e: Dictionary) -> void:
	word_glyph = String(e.get("glyph", "名"))
	word_name = String(e.get("name", ""))
	word_ink = Color(String(e.get("ink", "#2f7d86")))
	word_speed_mul = float(e.get("speed", 1.0))
	if b != null:
		max_hp = b.enemy_hp * float(e.get("hp", 1.0))
		hp = max_hp
		coin_min = maxi(1, int(e.get("coins", 2)) - 1)
		coin_max = int(e.get("coins", 2)) + 1
	if _wg != null and is_instance_valid(_wg):
		_wg.set_word(word_glyph, word_ink)


func setup(balance: BalanceData, hp_mul: float = 1.0) -> void:
	b = balance
	max_hp = balance.enemy_hp * hp_mul
	hp = max_hp
	contact_damage = balance.enemy_damage
	_speed = balance.flyer_speed


func _ready() -> void:
	if b == null:
		b = Balance.d
	collision_layer = 4          # 只作为"可碰撞/可踩"的对象；不当地板（载人靠主角侧处理）
	collision_mask = 0           # 穿墙飞，避免卡在岛体里
	z_index = 3
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_half * 2.0, _half * 1.5)
	cs.shape = rs
	add_child(cs)
	_wg = WordGlyph.new()
	_wg.base_font_size = Assets.cfg.enemy_font_size
	add_child(_wg)
	_wg.set_word(word_glyph, word_ink)
	_art = Assets.get_art("enemy_flyer")
	_half = float(b.tile_size) * 0.354
	home = position
	_phase = randf() * TAU
	_prev_pos = position
	_search = randf() * 0.4


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if b == null:
		b = Balance.d
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)

	_search -= delta
	if _search <= 0.0:
		_search = 0.4
		_target = get_tree().get_first_node_in_group("player") as Node2D

	# 极缓慢地把巡逻中心挪向玩家（所以它不会飞走失联，但也不会贴脸）
	if _target != null and is_instance_valid(_target):
		home.x = move_toward(home.x, _target.global_position.x, 26.0 * Balance.px * delta)
		home.y = move_toward(home.y, _target.global_position.y - 60.0 * Balance.px,
			12.0 * Balance.px * delta)

	# 平滑的正弦巡航：水平往返 + 上下起伏
	var tx := home.x + sin(_t * 1.05 + _phase) * 115.0 * Balance.px
	var ty := home.y + sin(_t * 1.7 + _phase) * 30.0 * Balance.px
	_prev_pos = global_position
	velocity = (Vector2(tx, ty) - global_position) * 2.6
	velocity = velocity.limit_length(_speed * word_speed_mul * 1.9)
	_apply_attract()
	move_and_slide()
	move_delta = global_position - _prev_pos
	if _wg != null and is_instance_valid(_wg):
		var was := _wg.flash
		_wg.flash = _flash > 0.0
		if was != _wg.flash:
			_wg.queue_redraw()


## 「慕」的副作用：飞怪也被牵过来
func _apply_attract() -> void:
	if not RunState.has_attract():
		return
	if _target == null or not is_instance_valid(_target):
		return
	var d := _target.global_position - global_position
	if d.length() > Balance.d.attract_radius:
		return
	velocity += d.normalized() * b.enemy_attract_speed


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
		velocity += knockback * 0.5
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
	if w != null and is_instance_valid(w):
		for i in range(randi_range(coin_min, coin_max)):
			var c := Coin.new()
			c.setup(Assets.cfg.color_coin)
			c.position = position + Vector2(randf_range(-12, 12), randf_range(-12, 8)) * Balance.px
			w.call_deferred("add_child", c)
	queue_free()
