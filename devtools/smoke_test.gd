extends Node
## 冒烟测试：自动跑一遍核心机制、截图、打印 PASS/FAIL。
## 运行：
##   Tools/Godot_console.exe --path . res://devtools/smoke_test.tscn

var _fails: Array[String] = []
var _main: Node
var _player: Player
var _world: GameWorld


func _ready() -> void:
	await get_tree().process_frame
	_main = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	_player = _main.player
	_world = _main.world

	await _test_spawn_and_terrain()
	await _test_move_and_jump()
	await _test_vanish_cycle()
	await _test_fall_damage()
	await _test_radicals()
	await _test_enemy_and_coins()
	await _shoot()

	print("\n==== 冒烟测试结束 ====")
	if _fails.is_empty():
		print("全部通过 ✔")
	else:
		print("失败 %d 项：" % _fails.size())
		for f in _fails:
			print("  ✘ ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait_physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _tile() -> int:
	return Balance.d.tile_size


# ── 1) 出生与地形 ──────────────────────────────────────
func _test_spawn_and_terrain() -> void:
	print("\n[1] 出生与地形")
	await _wait_physics(40)
	_check(_player.is_on_floor(), "主角落地")
	_check(absi(_player.global_position.x) < 200.0,
		"主角没有被弹飞（x=%.1f）" % _player.global_position.x)
	_check(_world.tile_count() > 40, "地形已生成（%d 块）" % _world.tile_count())
	_check(_player.hp >= _player.max_hp - 0.01, "出生没有受伤（hp=%.2f）" % _player.hp)

	# 台阶高度检查：相邻列的平台顶高度差不能超过 1 格（否则跳不上去 = 卡死）
	# 只看 0 层带平台所在的几行，别把层带中部的浮岛算进来。
	var max_step := 0
	var s := _world.world_seed
	for cx in range(-60, 60):
		var top_a := _column_top(cx, s)
		var top_b := _column_top(cx + 1, s)
		if top_a != 9999 and top_b != 9999:
			max_step = maxi(max_step, absi(top_a - top_b))
	_check(max_step <= 1, "平台台阶落差不超过 1 格（实际最大 %d 格）" % max_step)

	# 洞宽检查：0 层带里「整列都没有可站方块」的连续长度不能超过可跳跃距离
	var max_gap := 0
	var run := 0
	for cx in range(-400, 400):
		var has_floor := false
		for y in range(0, 3):
			if TerrainGen.is_solid(cx, y, s):
				has_floor = true
				break
		if has_floor:
			run = 0
		else:
			run += 1
			max_gap = maxi(max_gap, run)
	_check(max_gap <= 3, "连续空缺不超过 3 格（实际最大 %d 格，跳跃距离约 3.6 格）" % max_gap)


## 某列在「0 层带平台」几行里的平台顶行号；没有可站格则返回 9999
func _column_top(cx: int, s: int) -> int:
	for y in range(0, 4):
		if TerrainGen.is_solid(cx, y, s) and not TerrainGen.is_solid(cx, y - 1, s):
			return y
	return 9999


# ── 2) 移动与跳跃 ─────────────────────────────────────
func _test_move_and_jump() -> void:
	print("\n[2] 移动与跳跃")
	var x0 := _player.global_position.x
	var max_vel := 0.0
	var max_x := x0
	Input.action_press("move_right")
	for i in range(45):
		await get_tree().physics_frame
		max_vel = maxf(max_vel, _player.velocity.x)
		max_x = maxf(max_x, _player.global_position.x)
	Input.action_release("move_right")
	_check(max_vel > 150.0, "向右加速到接近上限（峰值 %.0f / 上限 %.0f）"
		% [max_vel, Balance.d.move_speed])
	_check(max_x > x0 + 60.0, "确实向右位移（%.0f -> %.0f）" % [x0, max_x])

	await _wait_physics(25)
	var y0 := _player.global_position.y
	var min_y := y0
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in range(30):
		await get_tree().physics_frame
		min_y = minf(min_y, _player.global_position.y)
	_check(min_y < y0 - 8.0, "跳跃生效（最高上移 %.0f px）" % (y0 - min_y))


# ── 3) 方块消失周期 ───────────────────────────────────
func _test_vanish_cycle() -> void:
	print("\n[3] 方块的消失周期（接触 -> 倒计时 -> 消失 -> 虚线残影）")
	await _wait_physics(10)
	var before := _world.destroyed_count()
	var counting := 0
	for c in _world.get_children():
		if c is SolidTile and (c as SolidTile).state != SolidTile.State.SOLID:
			counting += 1
	_check(counting > 0, "踩过的方块进入倒计时（%d 块）" % counting)

	var elapsed := 0.0
	while _world.destroyed_count() == before and elapsed < 8.0:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	_check(_world.destroyed_count() > before,
		"方块真的消失了（%d -> %d，耗时 %.1fs，基准 %.1fs）"
			% [before, _world.destroyed_count(), elapsed, Balance.d.vanish_time])
	var ghosts := 0
	for c in _world.get_children():
		if c is VoidGhost:
			ghosts += 1
	_check(ghosts > 0 or _world.destroyed_count() > before, "消失后留下虚线空位残影")


# ── 4) 掉落伤害 ───────────────────────────────────────
func _test_fall_damage() -> void:
	print("\n[4] 掉落伤害（仅长距离、量少、有上限、不致死）")
	# 清场：避免怪把主角打死、或捡到偏旁改变受伤系数，干扰本项测试
	RunState.radicals.clear()
	RunState.radicals_changed.emit()
	for c in _world.get_children():
		if c is RedBlock or c is RadicalPickup:
			c.queue_free()
	await _wait_physics(5)
	if _player.is_dead():
		_player.revive_state()
	_player.heal(99.0)

	# 4a) 真实长距离掉落：主角脚下平台的「下方」就是层带空隙，往下找一段空档
	var cx := int(floor(_player.global_position.x / float(_tile())))
	var cy := int(floor(_player.global_position.y / float(_tile())))
	var s := _world.world_seed
	var chosen_y := 0
	var found := false
	var want := 5   # 需要连续 5 格空（超过 4.5 格阈值）
	for dy in range(0, 40):
		var y := cy + dy
		var clear := true
		for j in range(0, want):
			if TerrainGen.is_solid(cx, y + j, s):
				clear = false
				break
		if clear:
			chosen_y = y
			found = true
			break
	_check(found, "找到一段 >=%d 格的空档用于测试" % want)
	if found:
		_player.position = Vector2(cx * _tile() + 24, chosen_y * _tile() + 24)
		_player.velocity = Vector2.ZERO
		var hp0 := _player.hp
		var elapsed := 0.0
		while elapsed < 5.0:
			await get_tree().physics_frame
			elapsed += 1.0 / 60.0
			if _player.is_on_floor() and _player.hp < hp0:
				break
		_check(_player.hp < hp0, "长距离掉落造成伤害（%.2f -> %.2f）" % [hp0, _player.hp])
		_check(_player.hp > 0.0, "掉落不会致死（剩余 %.2f 心）" % _player.hp)

	# 4b) 阈值与上限（单元级：直接调伤害计算，清掉无敌帧，不受外界干扰）
	_player.revive_state()
	_player._invuln = 0.0
	var hp := _player.hp
	_player._apply_fall_damage((Balance.d.fall_damage_min_tiles - 0.5) * float(_tile()))
	_check(hp - _player.hp < 0.01, "低于阈值的掉落不受伤")

	_player._invuln = 0.0
	hp = _player.hp
	_player._apply_fall_damage(4000.0)
	var dmg := hp - _player.hp
	_check(absf(dmg - Balance.d.fall_damage_max) < 0.01,
		"掉落伤害被上限截断（%.2f = 上限 %.2f）" % [dmg, Balance.d.fall_damage_max])

	# 4c) 连摔不掉到死
	_player.revive_state()
	_player._invuln = 0.0
	for i in range(8):
		_player._invuln = 0.0
		_player._apply_fall_damage(4000.0)
	_check(_player.hp >= 1.0 - 0.01, "连续重摔也永远剩至少 1 心（剩 %.2f）" % _player.hp)
	_player.heal(99.0)
	_player._invuln = 0.0

# ── 5) 偏旁 ───────────────────────────────────────────
func _test_radicals() -> void:
	print("\n[5] 偏旁：变字、被动、副作用")
	if _player.is_dead():
		_player.revive_state()
	_player.heal(99.0)
	RunState.radicals.clear()
	RunState.radicals_changed.emit()
	await get_tree().process_frame

	var lib: RadicalLibrary = load("res://data/radical_library.tres")
	_check(lib != null and lib.radicals.size() >= 6, "偏旁库加载（%d 个）"
		% (lib.radicals.size() if lib != null else 0))
	if lib == null:
		return
	var v0 := _player.vanish_factor
	RunState.add_radical(lib.find_by_id("mo_ri"))
	await get_tree().process_frame
	_check(_player.vanish_factor > v0, "「暮」让消失变慢（%.2f -> %.2f）"
		% [v0, _player.vanish_factor])
	_check(_player._glyph.text == "暮", "主角字形真的变成了「暮」（莫 + 日）")

	var m0 := _player.move_factor
	RunState.add_radical(lib.find_by_id("mo_tu"))
	await get_tree().process_frame
	_check(_player.move_factor < m0, "「墓」的副作用让移速变慢（%.2f -> %.2f）"
		% [m0, _player.move_factor])

	_check(not _player.attract, "还没装「慕」时没有磁吸")
	RunState.add_radical(lib.find_by_id("mo_xin"))
	await get_tree().process_frame
	_check(_player.attract, "「慕」带来磁吸")
	_check(RunState.radicals.size() <= RunState.slot_count,
		"装上的字不超过槽位（%d / %d）" % [RunState.radicals.size(), RunState.slot_count])

	# 「馍」立即回血
	_player.revive_state()
	_player._invuln = 0.0
	_player.take_damage(1.5)
	var hp0 := _player.hp
	RadicalEffects.on_pickup(_player, lib.find_by_id("mo_shi"))
	await get_tree().process_frame
	_check(_player.hp > hp0, "「馍」立即回血（%.2f -> %.2f）" % [hp0, _player.hp])

	# 「漠」主动技能：按 Q 出水柱，且有副作用（地面消失加速）
	RunState.radicals.clear()
	RunState.radicals.append(lib.find_by_id("mo_shui"))
	RunState.radicals_changed.emit()
	await get_tree().process_frame
	var vf0 := _player.vanish_factor
	_player.do_skill("skill_1")
	await get_tree().process_frame
	_check(_player.vanish_factor < vf0,
		"「漠」用完有副作用：地面消失加速（%.2f -> %.2f）" % [vf0, _player.vanish_factor])


# ── 6) 敌人与金币 ─────────────────────────────────────
func _test_enemy_and_coins() -> void:
	print("\n[6] 敌人、金币、攻击")
	if _player.is_dead():
		_player.revive_state()
	_player.heal(99.0)
	for c in _world.get_children():
		if c is InkShot or c is RedBlock or c is Coin:
			c.queue_free()
	await _wait_physics(4)

	var e := RedBlock.new()
	e.setup(Balance.d)
	e.position = _player.position + Vector2(170, -40)
	_world.add_child(e)
	await _wait_physics(20)
	if is_instance_valid(e):
		e.hit(99.0)
	await _wait_physics(6)
	var coins := 0
	for c in _world.get_children():
		if c is Coin:
			coins += 1
	_check(coins > 0, "击杀敌人掉落金币（%d 枚）" % coins)

	# 攻击能打出投射物
	for c in _world.get_children():
		if c is Coin:
			c.queue_free()
	Input.action_press("attack")
	await _wait_physics(6)
	Input.action_release("attack")
	var shots := 0
	for c in _world.get_children():
		if c is InkShot:
			shots += 1
	_check(shots > 0, "攻击产生投射物（%d 个）" % shots)


func _shoot() -> void:
	print("\n[7] 截图")
	await _wait_physics(10)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://last_run.png"
	img.save_png(path)
	print("    截图: ", ProjectSettings.globalize_path(path))


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ✔ ", label)
	else:
		print("  ✘ ", label)
		_fails.append(label)
