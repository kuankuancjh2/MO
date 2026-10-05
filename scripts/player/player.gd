class_name Player
extends CharacterBody2D
## 主角：一个「莫」字。
##
## 身份机制：他触碰到的方块会开始消失倒计时；碰到字块会把它撞碎并吸收那个字。
## 偏旁系统：携带偏旁通过「数值因子」改变属性（见 RadicalEffects / recalc_stats）。
## 掉落：世界向任意方向延伸，失足落下不会死，只会掉到下一层；
##       落地前按跳跃可以卸力免伤（太高就免不掉，固定扣 1 心）。
##
## 与敌人的接口约定（地怪和飞怪都实现同名方法，主角不需要知道具体类型）：
##   on_stomped(player) / try_contact_damage(player)

signal hp_changed(hp: float, max_hp: float)
signal died
signal layer_changed(layer: int, went_down: bool)

var b: BalanceData

var max_hp: float = 5.0
var hp: float = 5.0

## 商店打开时锁住操作
var input_locked := false

## ── 由偏旁聚合出来的属性（1.0 = 无影响）──────────────
var vanish_factor: float = 1.0
var move_factor: float = 1.0
var damage_factor: float = 1.0
var vision_factor: float = 1.0
var attack_factor: float = 1.0
var attract: bool = false

var facing: int = 1

var _dead := false
var _attack_cd := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _airborne := false
var _peak_y := 0.0
var _layer := 0
var _invuln := 0.0
var _landing_cancel := 0.0    ## > 0 表示"刚在air里按过跳跃"，可用于卸力
var _hit_flash := 0.0
var _timed: Array = []
var _skill_cds: Dictionary = {}
var _was_airborne_for_sfx := false

var _glyph: Label


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

	_glyph = Assets.make_label("莫", Assets.cfg.player_font_size, Assets.cfg.color_player)
	_glyph.size = Vector2(b.tile_size * 2, b.tile_size * 2)
	_glyph.position = -_glyph.size * 0.5
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_glyph)

	_layer = TerrainGen.layer_of(global_position.y, b.tile_size)
	RunState.radicals_changed.connect(_on_radicals_changed)
	_on_radicals_changed()
	hp_changed.emit(hp, max_hp)


# ── 变字 ───────────────────────────────────────────────

func _on_radicals_changed() -> void:
	recalc_stats()
	_update_form()


## 「莫」碰到字块就变成新的字 —— 主题的直接体现。
func _update_form() -> void:
	if _glyph == null:
		return
	var ch := "莫"
	if not RunState.radicals.is_empty():
		ch = RunState.radicals[RunState.radicals.size() - 1].composed_char
	_glyph.text = ch


# ── 属性聚合 ───────────────────────────────────────────

func recalc_stats() -> void:
	vanish_factor = _meta_factor("vanish")
	move_factor = _meta_factor("move")
	damage_factor = 1.0
	vision_factor = 1.0
	attack_factor = 1.0
	attract = false
	for r in RunState.radicals:
		vanish_factor *= r.vanish_slow_factor
		move_factor *= r.move_factor
		damage_factor *= r.damage_taken_factor
		vision_factor *= r.vision_factor
		attack_factor *= r.attack_factor
		if r.attract:
			attract = true
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

	var on_floor := is_on_floor()
	_coyote = b.coyote_time if on_floor else maxf(_coyote - delta, 0.0)

	var want_jump := false
	var want_attack := false
	var want_skill_1 := false
	var want_skill_2 := false
	var dir := 0.0
	if not input_locked:
		dir = Input.get_axis("move_left", "move_right")
		want_jump = Input.is_action_just_pressed("jump")
		want_attack = Input.is_action_pressed("attack")
		want_skill_1 = Input.is_action_just_pressed("skill_1")
		want_skill_2 = Input.is_action_just_pressed("skill_2")
	else:
		dir = 0.0

	if want_jump:
		_buffer = b.jump_buffer_time
		if not on_floor:
			# 空中按跳跃 = 准备卸力（本作没有二段跳，这一按就是「落地前按跳跃」）
			_landing_cancel = b.fall_landing_cancel_window
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if not on_floor:
		velocity.y = minf(velocity.y + b.gravity * delta, b.max_fall_speed)
	if not input_locked and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= b.jump_cut_factor
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = b.jump_velocity
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
	_update_layer()
	_update_glyph()


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
			if _was_airborne_for_sfx:
				_was_airborne_for_sfx = false
				Sfx.play_varied("land")
			_apply_fall_damage(global_position.y - _peak_y)
	else:
		if not _airborne:
			_airborne = true
			_was_airborne_for_sfx = true
			_peak_y = global_position.y
		_peak_y = minf(_peak_y, global_position.y)


func _apply_fall_damage(drop_px: float) -> void:
	var tiles := drop_px / float(b.tile_size)
	if tiles < b.fall_safe_tiles:
		return                                    # 不高，什么都不发生
	var cancelable := tiles < b.fall_cancel_max_tiles
	if cancelable and _landing_cancel > 0.0:
		_banner("卸力！")
		_landing_cancel = 0.0
		return                                    # 落地前按了跳跃 —— 免伤
	var dmg := b.fall_damage_amount * damage_factor
	if not b.fall_damage_lethal:
		dmg = minf(dmg, hp - 1.0)                 # 摔不死：永远留 1 心
	if dmg > 0.01:
		take_damage(dmg, "fall")
		if not cancelable:
			_banner("摔得不轻（太高，没卸掉）")


## 当前是否处于"会受伤、但还来得及卸力"的下落中（用来给玩家提示）
func fall_danger() -> float:
	if is_on_floor():
		return 0.0
	var tiles := (global_position.y - _peak_y) / float(b.tile_size)
	if tiles < b.fall_safe_tiles:
		return 0.0
	if tiles < b.fall_cancel_max_tiles:
		return 1.0     # 可卸力
	return 2.0         # 太高，卸不掉


# ── 碰撞：方块 / 字块 / 敌人 ───────────────────────────

func _touch_bodies(pre_vel: Vector2) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col: Object = c.get_collider()
		if col is SolidTile:
			(col as SolidTile).on_touched(self)
		elif col is WordBlock:
			(col as WordBlock).on_touched(self)
		elif col != null and col.has_method("on_stomped"):
			var n := c.get_normal()
			# 从上方落下踩到头顶 —— 用碰撞前速度判断，因为 move_and_slide 会回写 velocity
			if n.y < -0.5 and pre_vel.y > 0.0:
				col.call("on_stomped", self)
			else:
				col.call("try_contact_damage", self)


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
		# 下落有危险 —— 字体变红闪烁，提示"该按跳跃了"
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var danger_col: Color = Assets.cfg.color_tile_warn if danger >= 2.0 else Assets.cfg.color_coin
		col = danger_col.lerp(Assets.cfg.color_player, pulse * 0.5)
	elif _hit_flash > 0.0:
		col = Assets.cfg.color_tile_warn
	elif _invuln > 0.0:
		col = Assets.cfg.color_player.lerp(Color(1, 1, 1, 0.3), 0.5)
	_glyph.add_theme_color_override("font_color", col)
	_glyph.rotation = deg_to_rad(-6.0 * facing)


# ── 攻击 / 技能 ────────────────────────────────────────

## 攻击朝鼠标方向射出（也支持纯键盘：没有鼠标输入时用朝向）
func aim_direction() -> Vector2:
	var m := get_global_mouse_position()
	var d := m - global_position
	if d.length() < 12.0:
		return Vector2(float(facing), 0.0)
	return d.normalized()


func do_attack() -> void:
	_attack_cd = b.attack_cooldown
	var dir := aim_direction()
	if absf(dir.x) > 0.15:
		facing = 1 if dir.x > 0.0 else -1
	shoot(dir, b.attack_damage * attack_factor, b.projectile_speed,
		b.projectile_life, 9.0, Assets.cfg.color_player)


## 也用于技能：可以指定从哪儿、往哪射
func shoot(dir: Vector2, dmg: float, speed: float, life: float, size: float, color: Color,
		knockback: float = 160.0, from: Vector2 = Vector2.INF) -> void:
	var shot := InkShot.new()
	shot.setup(dir, dmg, speed, life, size, color, knockback)
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


# ── 受伤 / 回血 / 弹起 ─────────────────────────────────

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


## 踩到怪头上弹起
func bounce(factor: float = 1.0) -> void:
	velocity.y = b.stomp_bounce * factor
	_airborne = false        # 重置下落起点，免得弹起被算成"掉落"
	_landing_cancel = 0.0


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
