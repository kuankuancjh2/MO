class_name RadicalEnemy
extends AnimatableBody2D
## 红色偏旁怪：稀有的漂浮怪，身上是一个**红色偏旁/字**。
##
## 碰到它不掉血 —— 而是**注入一个临时效果**：有正面也有负面。
## 所以「要不要主动撞上去赌一把」是一个真实的决策。
##
## 踩它 / 撞它 都会触发效果（想主动吸就走过去，想躲就绕开），触发后它消失。

## 效果表。kind 由 _apply() 分发。
## positive 只用于文案颜色（绿/红），行为完全由 kind 决定。
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

var _speed := 58.0
var _dead := false
var _flash := 0.0
var _t := 0.0
var _target: Node2D
var _search := 0.0
var _half := 17.0
var _vel := Vector2.ZERO
var _collected := false


func setup(balance: BalanceData, which: int = -1) -> void:
	b = balance
	var i := which
	if i < 0:
		i = randi() % EFFECTS.size()
	i = clampi(i, 0, EFFECTS.size() - 1)
	effect = EFFECTS[i]


func kind() -> String:
	return String(effect.get("kind", ""))


func glyph() -> String:
	return String(effect.get("glyph", "?"))


func _ready() -> void:
	if b == null:
		b = Balance.d
	collision_layer = 4          # 只作为"可碰撞/可打中"的对象，不当地板（踩上去不该能站）
	collision_mask = 0
	z_index = 3
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = _half
	cs.shape = c
	add_child(cs)
	_search = randf() * 0.4


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
		if d.length() > 6.0:
			_vel = _vel.lerp(d.normalized() * _speed, clampf(delta * 1.6, 0.0, 1.0))
	position += _vel * delta
	position.y += sin(_t * 2.6) * 0.4
	queue_redraw()


## 侧碰：注入效果（不扣血）
func try_contact_damage(p: Player) -> void:
	_consume(p)


## 踩头：同样注入效果（想主动吸就踩它）
func on_stomped(p: Player) -> void:
	p.bounce(0.7)
	_consume(p)


func hit(_damage: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	# 打不死它 —— 它就是来跟你赌一把的
	_flash = 0.16
	queue_redraw()


func _consume(p: Player) -> void:
	if _dead or _collected:
		return
	_collected = true
	_dead = true
	_apply(p)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_text"):
		var pos_v: bool = bool(effect.get("positive", false))
		main.announce_text(String(effect.get("text", "")), pos_v)
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
	var red := Color(1.0, 0.28, 0.28)
	if _flash > 0.0:
		red = Color.WHITE
	# 圆盘底
	draw_circle(Vector2.ZERO, _half, Color(0.10, 0.06, 0.08, 0.85))
	draw_arc(Vector2.ZERO, _half, 0.0, TAU, 28, red, 2.5)
	var f := Assets.font
	if f != null:
		var ch := glyph()
		var fs := Assets.cfg.radical_font_size
		var sz := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(-sz.x * 0.5, sz.y * 0.5 - 5.0), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)
