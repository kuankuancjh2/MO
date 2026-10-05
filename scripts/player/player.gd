class_name Player
extends CharacterBody2D
## 主角：一个「莫」字。
##
## 身份机制：他触碰到的方块会开始消失倒计时；方块碎了会露出藏在里面的偏旁。
##
## ★ 骑怪：踩到任何怪头上都不会杀死它、也不会掉血 ——
##   而是**站在它身上被它带着走**，像骑一个无法控制的东西（怪到哪你到哪）。
##   所以怪既是威胁，也是交通工具。
##
## 掉落：世界向任意方向延伸，失足落下不会死，只会掉到下一层；
##       落地前按跳跃可以卸力免伤（太高就免不掉，固定扣 1 心）。
##
## 视觉：assets/art/player*.png 存在就用图，不存在就用「莫」字。

signal hp_changed(hp: float, max_hp: float)
signal died
signal layer_changed(layer: int, went_down: bool)

var b: BalanceData

var max_hp: float = 5.0
var hp: float = 5.0
var input_locked := false

## ── 由偏旁聚合出来的属性 ───────────────────────────────
var vanish_factor: float = 1.0
var move_factor: float = 1.0
var damage_factor: float = 1.0
var vision_factor: float = 1.0
var attack_factor: float = 1.0
var attack_cd_factor: float = 1.0
var jump_factor: float = 1.0
var attract: bool = false
var attract_radius_mul: float = 1.0
## 组合技带来的开关
var water_count: int = 3
var water_heals: bool = false
var attack_breaks_blocks: bool = false
var regen_period: float = 0.0
## 永久特性
var can_double_jump: bool = false

var facing: int = 1
var riding: Node2D = null

var _dead := false
var _attack_cd := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _airborne := false
var _peak_y := 0.0
var _layer := 0
var _invuln := 0.0
var _landing_cancel := 0.0
var _hit_flash := 0.0
var _timed: Array = []
var _skill_cds: Dictionary = {}
var _air_jumps := 0
var _attack_anim := 0.0
var _anim_t := 0.0
var _regen_t := 0.0

var _glyph: Label
var _sprite: Sprite2D
var _idle_frames: Array = []
var _run_frames: Array = []
var _jump_art: Texture2D
var _fall_art: Texture2D
var _attack_frames: Array = []
var _ride_art: Texture2D


func _ready() -> void:
	b = Balance.d
	max_hp = float(b.player_max_hp) + float(MetaState.get_upgrade("hp"))
	hp = max_hp
	collision_layer = 2
	collision_mask = 1 | 4

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(b.player_size, b.player_size)
	cs.shape = rs
	add_child(cs)

	_sprite = Sprite2D.new()
	_sprite.visible = false
	add_child(_sprite)

	_glyph = Assets.make_label("莫", Assets.cfg.player_font_size, Assets.cfg.color_player)
	_glyph.size = Vector2(b.tile_size * 2, b.tile_size * 2)
	_glyph.position = -_glyph.size * 0.5
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_glyph)

	_load_art()
	_layer = TerrainGen.layer_of(global_position.y, b.tile_size)
	RunState.radicals_changed.connect(_on_radicals_changed)
	_on_radicals_changed()
	hp_changed.emit(hp, max_hp)


func _load_art() -> void:
	_idle_frames = Assets.get_frames("player_idle")
	_run_frames = Assets.get_frames("player_run")
	_attack_frames = Assets.get_frames("player_attack")
	_jump_art = Assets.get_art("player_jump")
	_fall_art = Assets.get_art("player_fall")
	_ride_art = Assets.get_art("player_ride")
	if _idle_frames.is_empty():
		var single := Assets.get_art("player")
		if single != null:
			_idle_frames = [single]
	# 有图就把字缩小叠在图上（"墨迹上浮着一个字"）
	var has_art := not _idle_frames.is_empty() or _jump_art != null
	_glyph.add_theme_font_size_override("font_size",
		int(Assets.cfg.player_font_size * (0.62 if has_art else 1.0)))


# ── 变字 / 属性 ────────────────────────────────────────

func _on_radicals_changed() -> void:
	recalc_stats()
	_update_form()


func _update_form() -> void:
	if _glyph == null:
		return
	var ch := "莫"
	if not RunState.radicals.is_empty():
		ch = RunState.radicals[RunState.radicals.size() - 1].composed_char
	_glyph.text = ch


func recalc_stats() -> void:
	vanish_factor = _meta_factor("vanish")
	move_factor = _meta_factor("move")
	damage_factor = 1.0
	vision_factor = 1.0
	attack_factor = 1.0
	attack_cd_factor = 1.0
	jump_factor = 1.0
	attract = false
	attract_radius_mul = 1.0
	water_count = 3
	water_heals = false
	attack_breaks_blocks = false
	regen_period = 0.0
	var trait_dj := MetaState.has_trait("double_jump")

	for r in RunState.radicals:
		vanish_factor *= r.vanish_slow_factor
		move_factor *= r.move_factor
		damage_factor *= r.damage_taken_factor
		vision_factor *= r.vision_factor
		attack_factor *= r.attack_factor
		attack_cd_factor *= r.attack_cooldown_factor
		jump_factor *= r.jump_factor
		if r.attract:
			attract = true
		if r.regen_period > 0.0:
			regen_period = r.regen_period if regen_period <= 0.0 \
				else minf(regen_period, r.regen_period)
		if r.unlocks_trait == "double_jump":
			trait_dj = true
			MetaState.unlock_trait("double_jump")   # 拿到就永久记住
	can_double_jump = trait_dj
	if not can_double_jump:
		_air_jumps = 0

	# 组合技
	var ids: Array = []
	for r in RunState.radicals:
		ids.append(r.id)
	Synergies.apply(self, ids)

	for m in _timed:
		match m.get("stat", ""):
			"vanish": vanish_factor *= m.value
			"move": move_factor *= m.value
			"damage": damage_factor *= m.value
			"vision": vision_factor *= m.value
			"attack": attack_factor *= m.value


func _meta_factor(stat: String) -> float:
	match stat:
		"vanish":
			return 1.0 + 0.08 * float(MetaState.get_upgrade("vanish"))
		"move":
			return 1.0 + 0.04 * float(MetaState.get_upgrade("speed"))
	return 1.0


func add_timed(stat: String, value: float, duration: float) -> void:
	_timed.append({"stat": stat, "value": value, "left": duration})
	recalc_stats()


# ── 物理 ───────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timed(delta)
	for k in _skill_cds.keys():
		_skill_cds[k] = maxf(float(_skill_cds[k]) - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_landing_cancel = maxf(_landing_cancel - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_attack_anim = maxf(_attack_anim - delta, 0.0)
	_anim_t += delta
	if regen_period > 0.0 and hp < max_hp:
		_regen_t += delta
		if _regen_t >= regen_period:
			_regen_t = 0.0
			heal(1.0)
	else:
		_regen_t = 0.0

	var on_floor := is_on_floor()
	_coyote = b.coyote_time if on_floor else maxf(_coyote - delta, 0.0)

	var dir := 0.0
	var want_jump := false
	var want_attack := false
	var want_skill_1 := false
	var want_skill_2 := false
	if not input_locked:
		dir = Input.get_axis("move_left", "move_right")
		want_jump = Input.is_action_just_pressed("jump")
		want_attack = Input.is_action_pressed("attack")
		want_skill_1 = Input.is_action_just_pressed("skill_1")
		want_skill_2 = Input.is_action_just_pressed("skill_2")

	if want_jump:
		_buffer = b.jump_buffer_time
		if not on_floor:
			# 空中按跳跃：既是"卸力"的输入，也可能是二段跳
			_landing_cancel = b.fall_landing_cancel_window
			if _coyote <= 0.0 and can_double_jump and _air_jumps > 0:
				_air_jumps -= 1
				velocity.y = b.jump_velocity * jump_factor
				_buffer = 0.0
				Sfx.play_varied("jump", 0.18)
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if not on_floor:
		velocity.y = minf(velocity.y + b.gravity * delta, b.max_fall_speed)
	else:
		_air_jumps = 1 if can_double_jump else 0
	if not input_locked and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= b.jump_cut_factor
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = b.jump_velocity * jump_factor
		_buffer = 0.0
		_coyote = 0.0
		Sfx.play_varied("jump")

	if absf(dir) > 0.05:
		facing = 1 if dir > 0.0 else -1
		velocity.x = move_toward(velocity.x, dir * b.move_speed * move_factor, b.accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, b.friction * delta)

	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if want_attack and _attack_cd <= 0.0:
		do_attack()
	if want_skill_1:
		do_skill("skill_1")
	if want_skill_2:
		do_skill("skill_2")

	var pre_vel := velocity
	move_and_slide()
	_track_fall()
	_touch_bodies(pre_vel)
	_apply_ride()
	_update_layer()
	_update_glyph()
	_update_visual()


## 骑在怪身上：把怪这一帧的**水平**位移补给主角（怪到哪你到哪）。
## 只补水平：竖直方向交给物理（碰撞会把主角顶起来、重力会让他跟着落下），
## 否则会重复计算、人在怪背上一跳一跳的。
func _apply_ride() -> void:
	if riding == null or not is_instance_valid(riding):
		riding = null
		return
	var d: Vector2 = riding.get("move_delta") if "move_delta" in riding else Vector2.ZERO
	if absf(d.x) > 0.0001:
		global_position.x += d.x


func _tick_timed(delta: float) -> void:
	if _timed.is_empty():
		return
	var dirty := false
	for i in range(_timed.size() - 1, -1, -1):
		_timed[i]["left"] -= delta
		if _timed[i]["left"] <= 0.0:
			_timed.remove_at(i)
			dirty = true
	if dirty:
		recalc_stats()


# ── 掉落 / 卸力 ────────────────────────────────────────

func _track_fall() -> void:
	if is_on_floor():
		if _airborne:
			_airborne = false
			Sfx.play_varied("land", 0.1)
			_apply_fall_damage(global_position.y - _peak_y)
	else:
		if not _airborne:
			_airborne = true
			_peak_y = global_position.y
		_peak_y = minf(_peak_y, global_position.y)


func _apply_fall_damage(drop_px: float) -> void:
	var tiles := drop_px / float(b.tile_size)
	if tiles < b.fall_safe_tiles:
		return
	var cancelable := tiles < b.fall_cancel_max_tiles
	if cancelable and _landing_cancel > 0.0:
		_banner("卸力！")
		_landing_cancel = 0.0
		return
	var dmg := b.fall_damage_amount * damage_factor
	if not b.fall_damage_lethal:
		dmg = minf(dmg, hp - 1.0)
	if dmg > 0.01:
		take_damage(dmg, "fall")
		if not cancelable:
			_banner("摔得不轻（太高，没卸掉）")


func fall_danger() -> float:
	if is_on_floor():
		return 0.0
	var tiles := (global_position.y - _peak_y) / float(b.tile_size)
	if tiles < b.fall_safe_tiles:
		return 0.0
	if tiles < b.fall_cancel_max_tiles:
		return 1.0
	return 2.0


# ── 碰撞 ───────────────────────────────────────────────

func _touch_bodies(pre_vel: Vector2) -> void:
	var on_enemy := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col: Object = c.get_collider()
		if col is SolidTile:
			(col as SolidTile).on_touched(self)
		elif col != null and col.has_method("try_contact_damage"):
			var n := c.get_normal()
			var can_ride: bool = col.get("rideable") if "rideable" in col else true
			if can_ride and n.y < -0.5 and pre_vel.y > -1.0:
				# 站在怪头上 —— 骑上去，不杀它、也不掉血
				on_enemy = true
				riding = col as Node2D
			else:
				col.call("try_contact_damage", self)
	if not on_enemy:
		riding = null


func _update_layer() -> void:
	var l := TerrainGen.layer_of(global_position.y, b.tile_size)
	if l != _layer:
		var went_down := l > _layer
		_layer = l
		if went_down:
			MetaState.report_layer(l)
		layer_changed.emit(l, went_down)


func _update_glyph() -> void:
	if _glyph == null:
		return
	var col := Assets.cfg.color_player
	var danger := fall_danger()
	if danger > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var danger_col: Color = Assets.cfg.color_tile_warn if danger >= 2.0 else Assets.cfg.color_coin
		col = danger_col.lerp(Assets.cfg.color_player, pulse * 0.5)
	elif _hit_flash > 0.0:
		col = Assets.cfg.color_tile_warn
	elif _invuln > 0.0:
		col = Assets.cfg.color_player.lerp(Color(1, 1, 1, 0.3), 0.5)
	_glyph.add_theme_color_override("font_color", col)
	_glyph.rotation = deg_to_rad(-6.0 * facing)


## 图象：有 assets/art 就用图，没有就只显示「莫」字
func _update_visual() -> void:
	if _sprite == null:
		return
	if _sprite.texture == null and _idle_frames.is_empty() and _jump_art == null:
		return                                  # 完全没图，跳过
	var tex: Texture2D = null
	if riding != null and _ride_art != null:
		tex = _ride_art
	elif _attack_anim > 0.0 and not _attack_frames.is_empty():
		tex = _attack_frames[int((b.attack_cooldown - _attack_anim) * 14.0) % _attack_frames.size()]
	elif not is_on_floor():
		tex = _jump_art if velocity.y < 0.0 else _fall_art
		if tex == null:
			tex = _idle_frames[0] if not _idle_frames.is_empty() else null
	elif absf(velocity.x) > 20.0 and not _run_frames.is_empty():
		tex = _run_frames[int(_anim_t * 9.0) % _run_frames.size()]
	else:
		tex = _idle_frames[int(_anim_t * 4.0) % _idle_frames.size()] if not _idle_frames.is_empty() else null
	if tex != null:
		_sprite.texture = tex
		_sprite.visible = true
		_sprite.flip_h = facing < 0
	else:
		_sprite.visible = false


# ── 攻击 / 技能 ────────────────────────────────────────

func aim_direction() -> Vector2:
	var m := get_global_mouse_position()
	var d := m - global_position
	if d.length() < 12.0:
		return Vector2(float(facing), 0.0)
	return d.normalized()


func do_attack() -> void:
	_attack_cd = b.attack_cooldown * attack_cd_factor
	_attack_anim = b.attack_cooldown * attack_cd_factor
	var dir := aim_direction()
	if absf(dir.x) > 0.15:
		facing = 1 if dir.x > 0.0 else -1
	shoot(dir, b.attack_damage * attack_factor, b.projectile_speed,
		b.projectile_life, 9.0, Assets.cfg.color_player, 160.0, attack_breaks_blocks)


func shoot(dir: Vector2, dmg: float, speed: float, life: float, size: float, color: Color,
		knockback: float = 160.0, breaks: bool = false, from: Vector2 = Vector2.INF) -> void:
	var shot := InkShot.new()
	shot.setup(dir, dmg, speed, life, size, color, knockback, false, breaks)
	var origin := from if from != Vector2.INF else position + Vector2(facing * 20.0, -2.0)
	shot.position = origin
	get_parent().add_child(shot)


func do_skill(action: String) -> void:
	var r := RunState.find_active_skill(action)
	if r == null:
		return
	if float(_skill_cds.get(action, 0.0)) > 0.0:
		return
	_skill_cds[action] = r.cooldown
	RadicalEffects.cast_active(self, r)


func skill_ready(action: String) -> float:
	return float(_skill_cds.get(action, 0.0))


# ── 受伤 / 回血 ────────────────────────────────────────

func take_damage(amount: float, source: String = "") -> void:
	if _dead or _invuln > 0.0:
		return
	var dmg := amount
	if source != "fall":
		dmg *= damage_factor
	hp = maxf(hp - dmg, 0.0)
	_hit_flash = 0.18
	_invuln = 0.35
	Sfx.play_varied("hit")
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead:
		return
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func grant_shield(duration: float) -> void:
	_invuln = maxf(_invuln, duration)


func is_dead() -> bool:
	return _dead


func revive_state() -> void:
	_dead = false
	hp = max_hp
	_invuln = 0.0
	hp_changed.emit(hp, max_hp)


func _banner(text: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_text"):
		main.announce_text(text)
