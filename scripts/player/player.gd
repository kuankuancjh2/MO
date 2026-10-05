class_name Player
extends CharacterBody2D
## 主角：一个「莫」字。
##
## 身份机制：他触碰过的方块会开始消失倒计时（见 SolidTile）。
## 偏旁系统：携带偏旁会通过「数值因子」改变他的属性（见 RadicalEffects.recalc_stats）。
## 掉落：世界向任意方向延伸，失足落下不会死，只会掉到下一层 —— 掉太久会有一点掉落伤害。

signal hp_changed(hp: float, max_hp: float)
signal died
signal layer_changed(layer: int, went_down: bool)

var b: BalanceData

var max_hp: float = 5.0
var hp: float = 5.0

## ── 由偏旁聚合出来的属性（1.0 = 无影响）──────────────────
var vanish_factor: float = 1.0      ## >1 地面消失更慢
var move_factor: float = 1.0
var damage_factor: float = 1.0      ## <1 受伤更少
var vision_factor: float = 1.0      ## <1 视野变暗
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

## 临时修正：[{stat:String, value:float, left:float}]
var _timed: Array = []
var _skill_cds: Dictionary = {}

var _glyph: Label
var _hit_flash := 0.0


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


func _on_radicals_changed() -> void:
	recalc_stats()
	_update_form()


## 「莫」踩到偏旁就变成新的字 —— 这是主题的直接体现。
## 携带多个偏旁时，字形显示「最近吸收的那个字」。
func _update_form() -> void:
	if _glyph == null:
		return
	var ch := "莫"
	if not RunState.radicals.is_empty():
		ch = RunState.radicals[RunState.radicals.size() - 1].composed_char
	_glyph.text = ch


## ── 属性聚合 ────────────────────────────────────────────
func recalc_stats() -> void:
	vanish_factor = 1.0 * _meta_factor("vanish")
	move_factor = 1.0 * _meta_factor("move")
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


## 加一个限时属性修正（偏旁技能用，比如「漠」用完地面加速消失）
func add_timed(stat: String, value: float, duration: float) -> void:
	_timed.append({"stat": stat, "value": value, "left": duration})
	recalc_stats()


## ── 物理 ────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timed(delta)
	for k in _skill_cds.keys():
		_skill_cds[k] = maxf(float(_skill_cds[k]) - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)

	var on_floor := is_on_floor()
	_coyote = b.coyote_time if on_floor else maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_buffer = b.jump_buffer_time
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if not on_floor:
		velocity.y = minf(velocity.y + b.gravity * delta, b.max_fall_speed)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= b.jump_cut_factor
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = b.jump_velocity
		_buffer = 0.0
		_coyote = 0.0

	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.05:
		facing = 1 if dir > 0.0 else -1
		velocity.x = move_toward(velocity.x, dir * b.move_speed * move_factor, b.accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, b.friction * delta)

	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		do_attack()
	if Input.is_action_just_pressed("skill_1"):
		do_skill("skill_1")
	if Input.is_action_just_pressed("skill_2"):
		do_skill("skill_2")

	move_and_slide()
	_track_fall()
	_touch_tiles()
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


## 记录腾空期间到达过的最高点，落地时算出掉了多少。
## 普通起跳（约 2 格）不会触发；只有真的失足长距离下落才会受伤。
func _track_fall() -> void:
	if is_on_floor():
		if _airborne:
			_airborne = false
			_apply_fall_damage(global_position.y - _peak_y)
	else:
		if not _airborne:
			_airborne = true
			_peak_y = global_position.y
		_peak_y = minf(_peak_y, global_position.y)


func _apply_fall_damage(drop_px: float) -> void:
	var tiles := drop_px / float(b.tile_size)
	if tiles <= b.fall_damage_min_tiles:
		return
	var dmg := (tiles - b.fall_damage_min_tiles) * b.fall_damage_per_tile
	dmg = minf(dmg, b.fall_damage_max)
	if not b.fall_damage_lethal:
		# 「不会死掉」：掉落伤害永远留 1 心
		dmg = minf(dmg, hp - 1.0)
	dmg *= damage_factor
	if dmg > 0.01:
		take_damage(dmg, "fall")


func _touch_tiles() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col: Object = c.get_collider()
		if col is SolidTile:
			(col as SolidTile).on_touched(self)


func _update_layer() -> void:
	var l := TerrainGen.layer_of(global_position.y, b.tile_size)
	if l != _layer:
		var went_down := l > _layer   # y 轴向下为正 —— 层号变大 = 掉到更下面一层
		_layer = l
		if went_down:
			MetaState.report_layer(l)
		layer_changed.emit(l, went_down)


func _update_glyph() -> void:
	if _glyph == null:
		return
	var col := Assets.cfg.color_player
	if _hit_flash > 0.0:
		col = Assets.cfg.color_tile_warn
	elif _invuln > 0.0:
		col = Assets.cfg.color_player.lerp(Color(1, 1, 1, 0.3), 0.5)
	_glyph.add_theme_color_override("font_color", col)
	_glyph.rotation = deg_to_rad(-6.0 * facing)


## ── 攻击 / 技能 ─────────────────────────────────────────
func do_attack() -> void:
	_attack_cd = b.attack_cooldown
	shoot(Vector2(facing, 0.0), b.attack_damage * attack_factor, b.projectile_speed,
		b.projectile_life, 9.0, Assets.cfg.color_player)


func shoot(dir: Vector2, dmg: float, speed: float, life: float, size: float, color: Color,
		knockback: float = 160.0) -> void:
	var shot := InkShot.new()
	shot.setup(dir, dmg, speed, life, size, color, knockback)
	shot.position = position + Vector2(facing * 20.0, -2.0)
	get_parent().add_child(shot)


func do_skill(action: String) -> void:
	var r := RunState.find_active_skill(action)
	if r == null:
		return
	if float(_skill_cds.get(action, 0.0)) > 0.0:
		return
	_skill_cds[action] = r.cooldown
	RadicalEffects.cast_active(self, r)


## ── 受伤 / 回血 ─────────────────────────────────────────
func take_damage(amount: float, source: String = "") -> void:
	if _dead or _invuln > 0.0:
		return
	var dmg := amount
	if source != "fall":
		dmg *= damage_factor
	hp = maxf(hp - dmg, 0.0)
	_hit_flash = 0.18
	_invuln = 0.35
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead:
		return
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func is_dead() -> bool:
	return _dead


func revive_state() -> void:
	_dead = false
	hp = max_hp
	hp_changed.emit(hp, max_hp)
