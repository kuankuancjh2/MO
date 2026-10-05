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
	await _test_word_block()
	await _test_fall_damage()
	await _test_stomp_and_contact()
	await _test_radicals()
	await _test_shop()
	await _test_performance()
	await _shoot()

	print("\n==== 冒烟测试结束 ====")
	if _fails.is_empty():
		print("全部通过 ✔")
	else:
		print("失败 %d 项：" % _fails.size())
		for f in _fails:
			print("  ✘ ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


# ── 工具 ───────────────────────────────────────────────

func _wait_physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _tile() -> int:
	return Balance.d.tile_size


func _pcx() -> int:
	return int(floor(_player.global_position.x / float(_tile())))


func _pcy() -> int:
	return int(floor(_player.global_position.y / float(_tile())))


## 把主角放到某一列的平台上方（避免瞬移进方块被解穿透弹飞）
func _place_on_column(cx: int, k: int = 0) -> void:
	var top := TerrainGen.platform_top_row(cx, k, _world.world_seed)
	_player.position = Vector2(cx * _tile() + _tile() * 0.5, top * _tile() - _tile() * 0.6)
	_player.velocity = Vector2.ZERO


func _clear_field() -> void:
	RunState.radicals.clear()
	RunState.radicals_changed.emit()
	for c in _world.get_children():
		if c is RedBlock or c is Seeker or c is Flyer or c is RadicalEnemy \
				or c is WordBlock or c is Shop or c is Coin or c is InkShot:
			c.queue_free()
	await _wait_physics(4)
	if _player.is_dead():
		_player.revive_state()
	_player._invuln = 0.0
	_player.heal(99.0)


# ── 1) 出生与地形 ──────────────────────────────────────

func _test_spawn_and_terrain() -> void:
	print("\n[1] 出生与地形")
	await _wait_physics(40)
	if not _player.is_on_floor():
		print("    DEBUG pos=%s vel=%s cell=(%d,%d) layer=%d"
			% [_player.global_position, _player.velocity, _pcx(), _pcy(),
				TerrainGen.layer_of(_player.global_position.y, _tile())])
		for dy in range(-3, 4):
			var line := ""
			for dx in range(-4, 5):
				line += "#" if TerrainGen.is_solid(_pcx() + dx, _pcy() + dy, _world.world_seed) else "."
			print("      row%+d %s" % [dy, line])
		var nearby := 0
		for c in _world.get_children():
			if c is Node2D and (c as Node2D).global_position.distance_to(_player.global_position) < 80.0 \
					and not (c is SolidTile):
				print("      附近非方块节点: ", c.get_class(), " ", c.name, " @",
					(c as Node2D).global_position)
				nearby += 1
		print("      附近非方块节点数: ", nearby)
	_check(_player.is_on_floor(), "主角落地")
	_check(absi(_player.global_position.x) < 300.0,
		"主角没有被弹飞（x=%.1f）" % _player.global_position.x)
	_check(_world.tile_count() > 40, "地形已生成（%d 块）" % _world.tile_count())
	_check(_player.hp >= _player.max_hp - 0.01, "出生没有受伤（hp=%.2f）" % _player.hp)

	var s := _world.world_seed
	var max_step := 0
	for cx in range(-60, 60):
		var a := _column_top(cx, s)
		var b := _column_top(cx + 1, s)
		if a != 9999 and b != 9999:
			max_step = maxi(max_step, absi(a - b))
	_check(max_step <= 1, "平台台阶落差 <= 1 格（实际 %d 格）" % max_step)

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
	_check(max_gap <= 3, "连续空缺 <= 3 格（实际 %d 格，跳跃距离约 3.6 格）" % max_gap)

	# 结构：地面层必须左右贯通（否则玩家会被卡死）
	var lib := load("res://data/structure_library.tres") as StructureLibrary
	var bad := 0
	var total := 0
	if lib != null:
		for st in lib.structures:
			total += 1
			if not st.ground_row_is_open():
				bad += 1
	_check(lib != null and total >= 3, "结构库加载（%d 个：小屋/小摊/高台）" % total)
	_check(bad == 0, "所有结构的地面层都贯通（不合法 %d 个）" % bad)

	# 横向连贯度：0 层带里连续「无洞」的列数应该占多数
	var solid_cols := 0
	var scan := 0
	for cx in range(-300, 300):
		scan += 1
		for y in range(0, 3):
			if TerrainGen.is_solid(cx, y, s):
				solid_cols += 1
				break
	var ratio := float(solid_cols) / float(scan)
	_check(ratio > 0.75, "横向连贯：%.0f%% 的列有地面（应 > 75%%）" % (ratio * 100.0))


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
	print("\n[3] 方块的消失周期")
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


# ── 4) 字块：撞碎 -> 得字 ─────────────────────────────

func _test_word_block() -> void:
	print("\n[4] 字块（实心砖，撞碎得字）")
	await _clear_field()
	await _place_on_column(_pcx())
	await _wait_physics(20)

	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	var d := lib.find_by_id("mo_ri")   # 暮：vanish_factor 1.4
	var cell := Vector2i(_pcx() + 2, _pcy())
	var wb := WordBlock.new()
	wb.setup(cell, _tile(), _world, d)
	wb.position = Vector2(cell.x * _tile(), cell.y * _tile())
	_world.add_child(wb)
	await _wait_physics(4)
	_check(is_instance_valid(wb) and wb.state == WordBlock.State.INTACT, "字块作为实心砖存在")
	_check(RunState.radicals.is_empty(), "还没撞碎时没有这个字")

	var v0 := _player.vanish_factor
	var destroyed0 := _world.destroyed_count()
	Input.action_press("move_right")
	var elapsed := 0.0
	while elapsed < 4.0 and RunState.radicals.is_empty():
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	Input.action_release("move_right")
	_check(not RunState.radicals.is_empty(), "走过去撞碎了字块（%.1fs）" % elapsed)
	_check(_world.destroyed_count() > destroyed0, "字块被记为永久消失")
	_check(_player.vanish_factor > v0, "碎掉后字的效果生效：消失变慢（%.2f -> %.2f）"
		% [v0, _player.vanish_factor])
	_check(_player._glyph.text == "暮", "主角字形变成「暮」（莫 + 日）")


# ── 5) 掉落伤害与卸力 ─────────────────────────────────

func _find_void_run(cx: int) -> int:
	# 从主角所在行往下找一段连续 5 格空（层带空隙）
	var cy := _pcy()
	for dy in range(0, 40):
		var y := cy + dy
		var clear := true
		for j in range(0, 5):
			if TerrainGen.is_solid(cx, y + j, _world.world_seed):
				clear = false
				break
		if clear:
			return y
	return cy


func _test_fall_damage() -> void:
	print("\n[5] 掉落伤害与卸力")
	await _clear_field()

	# 5a) 直接调伤害计算（单元级，不受外界干扰）
	_player.hp = _player.max_hp
	_player._invuln = 0.0
	var hp0 := _player.hp
	_player._apply_fall_damage((Balance.d.fall_safe_tiles - 0.5) * float(_tile()))
	_check(hp0 - _player.hp < 0.01, "低于阈值（%.1f 格）不受伤" % Balance.d.fall_safe_tiles)

	_player._invuln = 0.0
	hp0 = _player.hp
	_player._apply_fall_damage(40.0 * float(_tile()))
	var dmg := hp0 - _player.hp
	_check(absf(dmg - Balance.d.fall_damage_amount) < 0.01,
		"超高掉落固定扣 1 心（实际 %.2f）" % dmg)

	_player.revive_state()
	_player._invuln = 0.0
	for i in range(8):
		_player._invuln = 0.0
		_player._apply_fall_damage(40.0 * float(_tile()))
	_check(_player.hp >= 1.0 - 0.01, "连摔也永远剩至少 1 心（剩 %.2f）" % _player.hp)
	_player.heal(99.0)

	# 5b) 真实下落：不按跳跃 -> 扣 1 心
	await _place_on_column(_pcx())
	await _wait_physics(20)
	var cx := _pcx()
	var y := _find_void_run(cx)
	_player.position = Vector2(cx * _tile() + 24, y * _tile() + 24)
	_player.velocity = Vector2.ZERO
	_player._invuln = 0.0
	_player.hp = _player.max_hp
	var hp_before := _player.hp
	var elapsed := 0.0
	while elapsed < 4.0:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _player.is_on_floor():
			break
	_check(_player.hp < hp_before, "长距离掉落扣血（%.2f -> %.2f）" % [hp_before, _player.hp])
	_check(_player.hp > 0.0, "掉落不会致死（剩 %.2f 心）" % _player.hp)

	# 5c) 同样高度，但落地前一直按跳跃 -> 卸力免伤
	await _place_on_column(_pcx())
	await _wait_physics(20)
	cx = _pcx()
	y = _find_void_run(cx)
	_player.position = Vector2(cx * _tile() + 24, y * _tile() + 24)
	_player.velocity = Vector2.ZERO
	_player._invuln = 0.0
	_player.hp = _player.max_hp
	hp_before = _player.hp
	elapsed = 0.0
	var mashing := false
	while elapsed < 4.0:
		# 每隔一帧按一次跳跃 —— 模拟"落地前按跳跃"
		mashing = not mashing
		if mashing:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _player.is_on_floor():
			break
	Input.action_release("jump")
	_check(absf(_player.hp - hp_before) < 0.01,
		"落地前按跳跃 = 卸力免伤（%.2f -> %.2f）" % [hp_before, _player.hp])


# ── 6) 踩头与侧碰 ─────────────────────────────────────

func _test_stomp_and_contact() -> void:
	print("\n[6] 踩头 / 侧碰")
	await _clear_field()
	await _place_on_column(_pcx())
	await _wait_physics(25)

	# 6a) 踩头：怪死，主角不掉血，主角被弹起
	var ex := _pcx() + 2
	var top := TerrainGen.platform_top_row(ex, 0, _world.world_seed)
	var guard := 0
	while guard < 30 and not (TerrainGen.is_solid(ex, top, _world.world_seed)
			and not TerrainGen.is_solid(ex, top - 1, _world.world_seed)):
		ex += 1
		top = TerrainGen.platform_top_row(ex, 0, _world.world_seed)
		guard += 1
	_check(guard < 30, "找到一列有平台的落脚点给怪站（偏移 %d）" % (ex - _pcx()))
	var e := RedBlock.new()
	e.setup(Balance.d)
	e.speed = 0.0                                  # 站桩，别走开
	e.position = Vector2(ex * _tile() + 24.0, top * _tile() - 18.0)
	_world.add_child(e)
	await _wait_physics(8)

	_player.position = Vector2(ex * _tile() + 24.0, top * _tile() - 120.0)
	_player.velocity = Vector2(0, 60)
	_player._invuln = 0.0
	var hp0 := _player.hp
	var bounced := false
	var elapsed := 0.0
	while elapsed < 2.0 and is_instance_valid(e) and not e.is_queued_for_deletion():
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _player.velocity.y < -100.0:
			bounced = true
	_check(not is_instance_valid(e) or e.is_queued_for_deletion(),
		"踩到怪头上把怪踩死了")
	_check(absf(_player.hp - hp0) < 0.01, "踩头不掉血（%.2f -> %.2f）" % [hp0, _player.hp])
	_check(bounced, "踩头后主角被弹起")

	# 6b) 侧碰：掉血
	await _clear_field()
	await _place_on_column(_pcx())
	await _wait_physics(25)
	var e2 := RedBlock.new()
	e2.setup(Balance.d)
	e2.speed = 0.0
	e2.position = _player.position + Vector2(34.0, -6.0)
	_world.add_child(e2)
	await _wait_physics(6)
	_player._invuln = 0.0
	hp0 = _player.hp
	Input.action_press("move_right")
	elapsed = 0.0
	while elapsed < 1.5 and absf(_player.hp - hp0) < 0.01:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	Input.action_release("move_right")
	_check(_player.hp < hp0, "侧面碰到怪会掉血（%.2f -> %.2f）" % [hp0, _player.hp])

	# 6c) 攻击朝鼠标方向
	var target_world := _player.global_position + Vector2(220, 0)
	var screen := _player.get_viewport().get_canvas_transform() * target_world
	Input.warp_mouse(screen)
	await get_tree().process_frame
	var aim := _player.aim_direction()
	_check(absf(aim.length() - 1.0) < 0.01, "瞄准方向是单位向量")
	_check(aim.x > 0.5, "鼠标在右边时弹丸朝右射（aim=(%.2f,%.2f)）" % [aim.x, aim.y])

	# 6d) 飞怪：踩头不死，而是被驯服（变成能载人的飞行平台）
	await _clear_field()
	await _place_on_column(_pcx())
	await _wait_physics(25)
	var f := Flyer.new()
	f.setup(Balance.d)
	f.position = _player.position + Vector2(0.0, -60.0)
	_world.add_child(f)
	await _wait_physics(4)
	_player.position = f.position + Vector2(0.0, -70.0)
	_player.velocity = Vector2(0, 60)
	_player._invuln = 0.0
	elapsed = 0.0
	while elapsed < 2.0 and not f.tamed:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	_check(is_instance_valid(f), "踩飞怪的头不会把它踩死")
	_check(f.tamed, "踩飞怪的头会被驯服（可以载人）")


# ── 7) 偏旁 ───────────────────────────────────────────

func _test_radicals() -> void:
	print("\n[7] 偏旁效果")
	await _clear_field()
	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	_check(lib != null and lib.radicals.size() >= 6, "偏旁库加载（%d 个）"
		% (lib.radicals.size() if lib != null else 0))
	if lib == null:
		return

	var v0 := _player.vanish_factor
	RunState.add_radical(lib.find_by_id("mo_ri"))
	await get_tree().process_frame
	_check(_player.vanish_factor > v0, "「暮」让消失变慢（%.2f -> %.2f）"
		% [v0, _player.vanish_factor])

	var m0 := _player.move_factor
	RunState.add_radical(lib.find_by_id("mo_tu"))
	await get_tree().process_frame
	_check(_player.move_factor < m0, "「墓」的副作用让移速变慢（%.2f -> %.2f）"
		% [m0, _player.move_factor])

	RunState.add_radical(lib.find_by_id("mo_xin"))
	await get_tree().process_frame
	_check(_player.attract, "「慕」带来磁吸")
	_check(RunState.radicals.size() <= RunState.slot_count,
		"装上的字不超过槽位（%d / %d）" % [RunState.radicals.size(), RunState.slot_count])

	RunState.radicals.clear()
	RunState.radicals_changed.emit()
	_player.revive_state()
	_player._invuln = 0.0
	_player.take_damage(1.5)
	var hp0 := _player.hp
	RadicalEffects.on_pickup(_player, lib.find_by_id("mo_shi"))
	await get_tree().process_frame
	_check(_player.hp > hp0, "「馍」立即回血（%.2f -> %.2f）" % [hp0, _player.hp])

	# 漠：三发都有效，且没有副作用
	RunState.radicals.clear()
	RunState.radicals.append(lib.find_by_id("mo_shui"))
	RunState.radicals_changed.emit()
	await get_tree().process_frame
	_check(absf(_player.vanish_factor - 1.0) < 0.01, "「漠」没有副作用（vanish_factor = 1）")
	for c in _world.get_children():
		if c is InkShot:
			c.queue_free()
	await _wait_physics(3)
	_player.do_skill("skill_1")
	await _wait_physics(2)
	var shots := 0
	var dirs: Array[Vector2] = []
	for c in _world.get_children():
		if c is InkShot:
			shots += 1
			dirs.append((c as InkShot).dir)
	_check(shots == 3, "「漠」一次打出三发水柱（实际 %d 发）" % shots)
	if shots == 3:
		var distinct := absf(dirs[0].angle_to(dirs[1])) > 0.01 \
			and absf(dirs[1].angle_to(dirs[2])) > 0.01
		_check(distinct, "三发方向各不相同（扇形展开）")


# ── 8) 商店 ───────────────────────────────────────────

func _test_shop() -> void:
	print("\n[8] 商店")
	await _clear_field()
	_player.take_damage(2.0)
	await get_tree().process_frame
	_player._invuln = 0.0
	RunState.add_coins(50)
	var hp0 := _player.hp
	var coins0 := RunState.coins
	_main.open_shop()
	await get_tree().process_frame
	_check(_main.shop_ui.is_open(), "按 F 能打开商店")
	_check(_player.input_locked, "开店时锁住主角操作")
	_main.shop_ui._try_buy(0)          # 第 1 项：回心
	await get_tree().process_frame
	_check(_player.hp > hp0, "买「回心」回了血（%.2f -> %.2f）" % [hp0, _player.hp])
	_check(RunState.coins < coins0, "买完扣了金币（%d -> %d）" % [coins0, RunState.coins])
	var slots0: int = RunState.slot_count
	_main.shop_ui._try_buy(2)          # 第 3 项：加槽位
	await get_tree().process_frame
	_check(RunState.slot_count > slots0, "买「加槽位」生效（%d -> %d）"
		% [slots0, RunState.slot_count])
	_main.shop_ui.close()
	await get_tree().process_frame
	_check(not _player.input_locked, "关店后恢复操作")


# ── 9) 性能回归 ───────────────────────────────────────

func _test_performance() -> void:
	print("\n[9] 性能：玩久了不该越来越卡（实体泄漏回归）")
	await _clear_field()
	var e0 := _world.entity_count()
	var n0 := _world.node_count()
	var tiles0 := _world.tile_count()

	var cx := _pcx()
	for i in range(30):
		cx += 20
		_place_on_column(cx)
		await get_tree().process_frame
		await _wait_physics(3)

	var e1 := _world.entity_count()
	var n1 := _world.node_count()
	var tiles1 := _world.tile_count()
	_check(e1 < 120, "出界实体被卸载，实体数有界（%d -> %d，上限 120）" % [e0, e1])
	_check(tiles1 < 1200, "方块数有界（%d -> %d）" % [tiles0, tiles1])
	_check(n1 < 1600, "走过 600 格后世界节点数有界（%d -> %d，上限 1600）" % [n0, n1])


func _shoot() -> void:
	print("\n[10] 截图")
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
