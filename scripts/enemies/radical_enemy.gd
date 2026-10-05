class_name RadicalEnemy
extends CharacterBody2D
## 红色偏旁怪：漂浮的怪，身上是一个**红色偏旁/字**。
##
## 碰到它不掉血 —— 而是**注入一个临时效果**：有正面也有负面。
## 所以「要不要主动撞上去赌一把」是一个真实的决策。
## 它**不能被骑**（rideable = false）：撞上去（包括从上方踩）就会触发效果然后消失。

const EFFECTS := [
	{"glyph": "心", "positive": true, "kind": "heal", "amount": 1.0, "duration": 0.0,
		"text": "红心：回 1 心"},
	{"glyph": "月", "positive": true, "kind": "shield", "amount": 0.0, "duration": 3.0,
		"text": "红月：3 秒无敌"},
	{"glyph": "日", "positive": false, "kind": "vanish_fast", "amount": 0.5, "duration": 5.0,
		"text": "红日：地面消失加速 5 秒"},
	{"glyph": "土", "positive": false, "kind": "break_floor", "amount": 5.0, "duration": 0.0,
		"text": "红土：脚下崩塌"},
]

var effect: Dictionary = {}
var b: BalanceData
var rideable := false
var move_delta := Vector2.ZERO

var _speed := 62.0
var _dead := false
var _flash := 0.0
var _t := 0.0
var _target: Node2D
var _search := 0.0
var _half := 17.0
var _collected := false
var _prev_pos := Vector2.ZERO
var _art: Texture2D


func setup(balance: BalanceData, which: int = -1) -> void:
	b = balance
	var i := which
	if i < 0:
		i = randi() % EFFECTS.size()
	effect = EFFECTS[clampi(i, 0, EFFECTS.size() - 1)]


func kind() -> String:
	return String(effect.get("kind", ""))


func glyph() -> String:
	return String(effect.get("glyph", "?"))


func _ready() -> void:
	if b == null:
		b = Balance.d
	collision_layer = 4
	collision_mask = 0
	z_index = 3
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = _half
	cs.shape = c
	add_child(cs)
	_art = Assets.get_art("enemy_radical")
	_search = randf() * 0.4
	_prev_pos = position


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_search -= delta
	if _search <= 0.0:
		_search = 0.4
		_target = get_tree().get_first_node_in_group("player") as Node2D

	if _target != null and is_instance_valid(_target):
		var d := _target.global_position - global_position
		var want := d.normalized() * _speed
		if d.length() < 40.0:
			want = Vector2.ZERO
		velocity = velocity.lerp(want, clampf(delta * 2.2, 0.0, 1.0))
	velocity.y += sin(_t * 2.6) * 6.0
	_prev_pos = global_position
	move_and_slide()
	move_delta = global_position - _prev_pos
	queue_redraw()


## 碰到就注入效果（不掉血）
func try_contact_damage(p: Player) -> void:
	_consume(p)


func hit(_damage: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	_flash = 0.16          # 打不死它 —— 它就是来跟你赌一把的
	queue_redraw()


func _consume(p: Player) -> void:
	if _dead or _collected:
		return
	_collected = true
	_dead = true
	_apply(p)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_text"):
		main.announce_text(String(effect.get("text", "")), bool(effect.get("positive", false)))
	var parent := get_parent()
	if parent != null:
		if parent.has_method("consume_cell"):
			parent.consume_cell(self)
		var burst := ShardBurst.new()
		burst.setup(position, Color(1.0, 0.30, 0.30), 10, 5.0, 160.0)
		parent.add_child(burst)
	queue_free()


func _apply(p: Player) -> void:
	var amount := float(effect.get("amount", 0.0))
	var duration := float(effect.get("duration", 0.0))
	match kind():
		"heal":
			p.heal(amount)
			Sfx.play("coin")
		"shield":
			p.grant_shield(duration)
			Sfx.play("transform")
		"vanish_fast":
			p.add_timed("vanish", amount, duration)
			Sfx.play("hit")
		"break_floor":
			var world := p.get_parent()
			if world != null and world.has_method("break_tiles_near"):
				world.break_tiles_near(p.global_position, int(amount))
			Sfx.play_varied("vanish")


func _draw() -> void:
	if _art != null:
		var sz := _art.get_size()
		draw_texture_rect(_art, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, 1))
		return
	var red := Color(1.0, 0.28, 0.28)
	if _flash > 0.0:
		red = Color.WHITE
	draw_circle(Vector2.ZERO, _half, Color(0.10, 0.06, 0.08, 0.85))
	draw_arc(Vector2.ZERO, _half, 0.0, TAU, 28, red, 2.5)
	var f := Assets.font
	if f != null:
		var ch := glyph()
		var fs := Assets.cfg.radical_font_size
		var sz2 := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(-sz2.x * 0.5, sz2.y * 0.5 - 5.0), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)
