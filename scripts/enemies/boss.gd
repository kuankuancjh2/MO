class_name Boss
extends CharacterBody2D
## Boss「有」。
##
## 剧情立意：莫 = 无；有 = 有。
## 莫走到哪里就把一切抹成虚无，「有」则不断地**造出东西**——造方块、造小怪、造投射物。
## 你要一边躲开它造出来的东西，一边把它自己抹掉。
##
## 行为：漂浮在场地中央，周期性做三件事：
##   1. 造物：在主角脚下造出临时方块（可以踩，但也会挡路/把人埋住）
##   2. 招募：召唤两个小怪
##   3. 吐字：朝主角打出一排投射物
## 血量掉一半后进入狂暴（动作更快）。

var b: BalanceData
var max_hp: float = 20.0
var hp: float = 20.0
var engaged := false

var _player: Node2D
var _phase_cd := 1.6
var _attack := 0
var _flash := 0.0
var _t := 0.0
var _home := Vector2.ZERO
var _vel := Vector2.ZERO
var _dead := false
var _contact_cd := 0.0
var _radius := 52.0

const ENGAGE_DIST := 420.0


func setup(balance: BalanceData, p: Node2D) -> void:
	b = balance
	_player = p
	max_hp = balance.boss_hp
	hp = max_hp


func _ready() -> void:
	if b == null:
		b = Balance.d
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 0
	z_index = 4
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = _radius * 0.7
	cs.shape = c
	add_child(cs)
	_home = position


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_p := _player.global_position - global_position
	if not engaged:
		if to_p.length() < ENGAGE_DIST:
			engaged = true
			_announce("「有」出现了 —— 它不停地造东西。把它抹掉。")
			Sfx.play("stomp")
		else:
			queue_redraw()
			return

	# 漂浮：保持在主角上方一点，并保持距离
	var drift := (to_p.normalized() * 120.0) if to_p.length() < 200.0 else Vector2.ZERO
	var target := _home + Vector2(clampf(to_p.x * 0.25, -180.0, 180.0), -120.0 + sin(_t * 1.6) * 26.0)
	_vel = _vel.lerp((target - global_position) * 1.6 + drift, clampf(delta * 3.0, 0.0, 1.0))
	velocity = _vel
	move_and_slide()

	# 碰人扣血
	if _contact_cd <= 0.0 and to_p.length() < _radius * 1.6:
		_player.take_damage(b.boss_contact_damage, "enemy")
		_contact_cd = 1.0

	var speed_mul := 0.55 if hp < max_hp * 0.5 else 1.0
	_phase_cd -= delta * (1.0 / speed_mul)
	if _phase_cd <= 0.0:
		_phase_cd = 2.4
		_do_attack()
	queue_redraw()


func _do_attack() -> void:
	_attack = (_attack + 1) % 3
	match _attack:
		0:
			_spawn_minions()
		1:
			_spawn_tiles()
		2:
			_spit()


func _spawn_minions() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in range(2):
		var e := RedBlock.new()
		e.setup(b)
		e.position = global_position + Vector2((i * 2 - 1) * 90.0, 20.0)
		parent.add_child(e)
	_announce("「有」造出了两个东西。")


func _spawn_tiles() -> void:
	# 在主角附近造出临时方块 —— 莫碰过它们照样会消失，所以它是"造"，你是"抹"
	var world := get_parent()
	if world == null or not world.has_method("spawn_temp_tile"):
		return
	var c := TerrainGen.fdiv(int(_player.global_position.x), Balance.d.tile_size)
	var row := TerrainGen.fdiv(int(_player.global_position.y), Balance.d.tile_size) + 3
	for dx in range(-2, 3):
		world.call("spawn_temp_tile", Vector2i(c + dx, row))
	_announce("「有」在你脚下造出了地面 —— 但莫碰过的都会消失。")

func _spit() -> void:
	var dir := (_player.global_position - global_position).normalized()
	for i in range(3):
		var d := dir.rotated((i - 1) * 0.22)
		var shot := InkShot.new()
		shot.setup(d, b.boss_shot_damage, 420.0, 2.2, 11.0, Color("#ff5a5a"), 0.0, true)
		shot.position = global_position
		get_parent().add_child(shot)


func hit(damage: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	hp -= damage
	_flash = 0.14
	Sfx.play_varied("hit", 0.15)
	queue_redraw()
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	_announce("「有」散了。你抹掉了「有」—— 但「莫」还在。")
	Sfx.play("shatter")
	var parent := get_parent()
	if parent != null:
		var burst := ShardBurst.new()
		burst.setup(global_position, Color(1.0, 0.4, 0.4), 26, 9.0, 300.0)
		parent.add_child(burst)
		if parent.has_method("consume_cell"):
			parent.consume_cell(self)
		# 战利品
		for i in range(8):
			var c := Coin.new()
			c.setup(Assets.cfg.color_coin)
			c.position = position + Vector2(randf_range(-40, 40), randf_range(-30, 10))
			parent.call_deferred("add_child", c)
	MetaState.add_souls(40)
	RunState.add_coins(20)
	queue_free()


func _announce(text: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_text"):
		main.announce_text(text, true)


func _draw() -> void:
	var col := Color(1.0, 0.36, 0.36)
	if _flash > 0.0:
		col = Color.WHITE
	var pulse := 1.0 + sin(_t * 3.0) * 0.04
	var art := Assets.get_art("boss_you")
	if art != null:
		var sz := art.get_size() * pulse
		draw_texture_rect(art, Rect2(-sz * 0.5, sz), false)
	else:
		draw_circle(Vector2.ZERO, _radius * pulse, Color(0.12, 0.05, 0.06, 0.92))
		draw_arc(Vector2.ZERO, _radius * pulse, 0.0, TAU, 40, col, 4.0)
		draw_arc(Vector2.ZERO, _radius * 0.72 * pulse, 0.0, TAU, 32,
			Color(col.r, col.g, col.b, 0.5), 2.0)
		var f := Assets.font
		if f != null:
			var fs := int(_radius * 1.5)
			var s := f.get_string_size("有", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, Vector2(-s.x * 0.5, s.y * 0.5 - 10.0), "有",
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
