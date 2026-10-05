extends Node
## 冒烟测试：自动跑一遍核心机制、截图、打印 PASS/FAIL。
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

	await _test_terrain()
	await _test_move_and_jump()
	await _test_vanish_cycle()
	await _test_hidden_radical()
	await _test_fall_and_cancel()
	await _test_ride()
	await _test_radicals_and_synergy()
	await _test_double_jump()
	await _test_shop()
	await _test_boss()
	await _test_ladder()
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


func _place_on_column(cx: int, k: int = 0) -> void:
	var row := TerrainGen.surface_row(cx, k, _world.world_seed)
	_player.position = Vector2(cx * _tile() + _tile() * 0.5, row * _tile() - _tile() * 0.6)
	_player.velocity = Vector2.ZERO


## 找一列「有地面」的落脚点（岛屿上）
func _find_land(cx: int, dir: int = 1) -> int:
	var s := _world.world_seed
	var x := cx
	for i in range(200):
		if TerrainGen.kind_at(x, 0, s) == 1:
			return x
		x += dir
	return cx


func _clear_field() -> void:
	RunState.radicals.clear()
	RunState.radicals_changed.emit()
	for c in _world.get_children():
		if c is EnemyBase or c is Flyer or c is RadicalEnemy or c is Boss \
				or c is Shop or c is Coin or c is InkShot or c is RadicalPickup:
			c.queue_free()
	await _wait_physics(4)
	if _player.is_dead():
		_player.revive_state()
	_player._invuln = 0.0
	_player.heal(99.0)


# ── 1) 地形：岛屿 + 桥 ────────────────────────────────

func _test_terrain() -> void:
	print("\n[1] 地形（岛屿 + 横向桥接）")
	await _wait_physics(40)
	_check(_player.is_on_floor(), "主角落地")
	_check(absi(_player.global_position.x) < 300.0,
		"主角没有被弹飞（x=%.1f）" % _player.global_position.x)
	_check(_world.tile_count() > 40, "地形已生成（%d 块）" % _world.tile_count())
	_check(_player.hp >= _player.max_hp - 0.01, "出生没有受伤（hp=%.2f）" % _player.hp)

	var s := _world.world_seed
	var land := 0
	var bridge := 0
	var gaps: Array = []
	var run := 0
	var seen_land := false
	var max_step := 0
	var prev_surface := -9999
	var islands := {}
	for cx in range(-400, 400):
		var kind := TerrainGen.kind_at(cx, 0, s)
		if kind == 1:
			land += 1
			islands[TerrainGen.column(cx, 0, s).z] = true
		elif kind == 2:
			bridge += 1
		else:
			run += 1
		if kind != 0:
			# 只统计"两侧都有落脚"的缺口；扫面两端的截断缺口不算
			if run > 0 and seen_land:
				gaps.append(run)
			run = 0
			seen_land = true
			var surf := TerrainGen.column(cx, 0, s).y
			if prev_surface > -9999:
				max_step = maxi(max_step, absi(surf - prev_surface))
			prev_surface = surf
		else:
			prev_surface = -9999

	var total := land + bridge
	for g in gaps:
		total += g
	var floor_ratio := float(land + bridge) / float(maxi(total, 1))
	_check(land > 60, "生成了多座岛（陆地列 %d）" % land)
	_check(islands.size() >= 4, "岛屿数量 >= 4（实际 %d 座）" % islands.size())
	_check(bridge > 10, "岛与岛之间有桥（桥列 %d）" % bridge)
	# 实测不同种子间在 75%~90% 波动，取 70% 作为有意义的底线
	_check(floor_ratio > 0.70, "横向连贯：%.0f%% 的列有落脚（应 > 70%%）" % (floor_ratio * 100.0))
	_check(max_step <= 1, "相邻落脚点落差 <= 1 格（实际 %d）" % max_step)

	# 缺口要么窄到能跳过去（<=3 格），要么宽得像断崖（>=8 格）；不能模棱两可
	var ambiguous := 0
	var pits := 0
	var narrow := 0
	var gap_start := 0
	var in_gap := false
	var gap_cursor := -400
	for g in gaps:
		gap_cursor += g
		if g <= 3:
			narrow += 1
		elif g >= 8:
			pits += 1
		else:
			ambiguous += 1
			print("      暧昧缺口: 宽 %d 格，结束于 cx≈%d" % [g, gap_cursor])
		gap_cursor += 1
	_check(ambiguous == 0,
		"没有「跳不过去又不够宽」的暧昧缺口（<=3格 %d 个 / >=8格断崖 %d 个 / 暧昧 %d 个）"
			% [narrow, pits, ambiguous])

	var lib := load("res://data/structure_library.tres") as StructureLibrary
	var bad := 0
	if lib != null:
		for st in lib.structures:
			if not st.ground_row_is_open():
				bad += 1
	_check(lib != null and lib.structures.size() >= 8,
		"结构库加载（%d 个）" % (lib.structures.size() if lib != null else 0))
	_check(bad == 0, "所有结构的地面层都贯通（不合法 %d 个）" % bad)


# ── 2) 移动跳跃 ───────────────────────────────────────

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
	_check(max_vel > 150.0, "向右加速到接近上限（峰值 %.0f）" % max_vel)
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
	_check(min_y < y0 - 8.0, "跳跃生效（上移 %.0f px）" % (y0 - min_y))


# ── 3) 消失周期 ───────────────────────────────────────

func _test_vanish_cycle() -> void:
	print("\n[3] 方块的消失周期（基准 %.1fs）" % Balance.d.vanish_time)
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
	_check(_world.destroyed_count() > before, "方块真的消失了（耗时 %.1fs）" % elapsed)


# ── 4) 偏旁藏在方块里 ─────────────────────────────────

func _test_hidden_radical() -> void:
	print("\n[4] 偏旁藏在方块里（碎开才露出来）")
	await _clear_field()
	await _place_on_column(_find_land(_pcx()))
	await _wait_physics(20)

	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	var d := lib.find_by_id("mo_ri")            # 暮：vanish_factor 1.4
	var cx := _find_land(_pcx()) + 1
	var surf := TerrainGen.surface_row(cx, 0, _world.world_seed)
	# 手动把主角脚下那一列的方块换成"藏着偏旁"的
	var key := Vector2i(cx, surf)
	var old = _world._tiles.get(key)
	if old != null and is_instance_valid(old):
		old.queue_free()
		_world._tiles.erase(key)
	var t := SolidTile.new()
	t.setup(key, _tile(), _world, 0, d)
	_world.add_child(t)
	_world._tiles[key] = t
	await _wait_physics(4)
	_check(TerrainGen.has_radical(cx, surf, _world.world_seed) or t.radical != null,
		"方块里确实藏着一个字")

	# 站上去 -> 碎掉 -> 偏旁浮出来 -> 飞向主角 -> 拿到
	_place_on_column(cx)
	var v0 := _player.vanish_factor
	var saw_pickup := false
	var elapsed := 0.0
	while elapsed < 6.0 and RunState.radicals.is_empty():
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		for c in _world.get_children():
			if c is RadicalPickup:
				saw_pickup = true
	_check(saw_pickup, "方块碎开后露出了偏旁")
	_check(not RunState.radicals.is_empty(), "偏旁飞向主角并被吸收（%.1fs）" % elapsed)
	_check(_player.vanish_factor > v0, "字的效果生效（消失变慢 %.2f -> %.2f）"
		% [v0, _player.vanish_factor])
	_check(_player._glyph.text == "暮", "主角字形变成「暮」")


# ── 5) 掉落与卸力 ─────────────────────────────────────

## 找一段"上下都有边界"的空档：连续 `fall_cells` 格空，紧跟着就是实心。
## 这样掉下去的下落高度是可控的（约 fall_cells - 0.83 格），
## 才能稳定落在"卸得掉"或"卸不掉"的区间里做对比。
## 返回 Vector2i(x, y)；找不到返回 (cx, cy)。
func _find_bounded_void(cx: int, fall_cells: int = 6) -> Vector2i:
	var s := _world.world_seed
	var cy := _pcy()
	for dc in range(0, 16):
		for sign_x in [1, -1]:
			var x: int = cx + dc * int(sign_x)
			for dy in range(-2, 40):
				var y := cy + dy
				var clear := true
				for j in range(0, fall_cells):
					if TerrainGen.is_solid(x, y + j, s):
						clear = false
						break
				if not clear:
					continue
				if TerrainGen.is_solid(x, y + fall_cells, s):
					return Vector2i(x, y)     # 正好掉 fall_cells 格后落地
	return Vector2i(cx, cy)


var _void_col := 0


func _test_fall_and_cancel() -> void:
	print("\n[5] 掉落伤害与卸力")
	await _clear_field()
	_player.hp = _player.max_hp
	_player._invuln = 0.0
	var hp0 := _player.hp
	_player._apply_fall_damage((Balance.d.fall_safe_tiles - 0.5) * float(_tile()))
	_check(hp0 - _player.hp < 0.01, "低于阈值不受伤")
	_player._invuln = 0.0
	hp0 = _player.hp
	_player._apply_fall_damage(40.0 * float(_tile()))
	_check(absf(hp0 - _player.hp - Balance.d.fall_damage_amount) < 0.01,
		"超高掉落固定扣 1 心")
	_player.revive_state()
	for i in range(8):
		_player._invuln = 0.0
		_player._apply_fall_damage(40.0 * float(_tile()))
	_check(_player.hp >= 1.0 - 0.01, "连摔也永远剩至少 1 心（剩 %.2f）" % _player.hp)

	# 真实下落：不按跳跃 -> 扣血（找一个有边界的空档，下落可控）
	var land := _find_land(_pcx() + 6)
	await _place_on_column(land)
	await _wait_physics(20)
	var spot := _find_bounded_void(_pcx(), 6)
	_player.position = Vector2(spot.x * _tile() + 24, spot.y * _tile() + 24)
	_player.velocity = Vector2.ZERO
	_player._invuln = 0.0
	_player.hp = _player.max_hp
	hp0 = _player.hp
	var start_y := _player.global_position.y
	var elapsed := 0.0
	while elapsed < 4.0:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _player.is_on_floor():
			break
	var drop := (_player.global_position.y - start_y) / float(_tile())
	_check(_player.hp < hp0, "长距离掉落扣血（掉 %.1f 格，%.2f -> %.2f）"
		% [drop, hp0, _player.hp])
	_check(_player.hp > 0.0, "掉落不会致死")

	# 同一个落点，落地前按跳跃 -> 卸力免伤
	var land2 := _find_land(_pcx() + 6)
	await _place_on_column(land2)
	await _wait_physics(20)
	spot = _find_bounded_void(_pcx(), 6)
	_player.position = Vector2(spot.x * _tile() + 24, spot.y * _tile() + 24)
	_player.velocity = Vector2.ZERO
	_player._invuln = 0.0
	_player.hp = _player.max_hp
	hp0 = _player.hp
	elapsed = 0.0
	var on := false
	while elapsed < 4.0:
		on = not on
		if on:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _player.is_on_floor():
			break
	Input.action_release("jump")
	_check(absf(_player.hp - hp0) < 0.01, "落地前按跳跃 = 卸力免伤（%.2f -> %.2f）"
		% [hp0, _player.hp])


# ── 6) 骑怪 ───────────────────────────────────────────

func _test_ride() -> void:
	print("\n[6] 踩怪 = 骑着走（不杀、不掉血）")
	await _clear_field()
	var cx := _find_land(_pcx() + 8)
	await _place_on_column(cx)
	await _wait_physics(25)

	var s := _world.world_seed
	var cx2 := _find_land(cx + 2)
	var surf := TerrainGen.surface_row(cx2, 0, s)
	var e := RedBlock.new()
	e.setup(Balance.d)
	e.speed = 110.0
	e.position = Vector2(cx2 * _tile() + _tile() * 0.5, surf * _tile() - _tile() * 0.375)
	_world.add_child(e)
	await _wait_physics(6)

	# 落到它头上
	_player.position = e.position + Vector2(0.0, -_tile() * 1.35)
	_player.velocity = Vector2(0, 60)
	_player._invuln = 0.0
	var hp0 := _player.hp
	var elapsed := 0.0
	while elapsed < 2.0 and _player.riding != e:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	_check(is_instance_valid(e), "踩到怪头上不会把怪踩死")
	_check(_player.riding == e, "主角骑在怪身上（riding）")
	_check(absf(_player.hp - hp0) < 0.01, "骑着不掉血（%.2f）" % _player.hp)

	var x0 := _player.global_position.x
	var moved_enemy := 0.0
	await _wait_physics(40)
	moved_enemy = absf(e.global_position.x - e.position.x)
	_check(absf(_player.global_position.x - x0) > 15.0,
		"被怪带着走（主角位移 %.0f px）" % absf(_player.global_position.x - x0))

	# 侧面碰仍然掉血
	await _clear_field()
	await _place_on_column(_find_land(_pcx()))
	await _wait_physics(25)
	var e2 := RedBlock.new()
	e2.setup(Balance.d)
	e2.speed = 0.0
	e2.position = _player.position + Vector2(_tile() * 0.72, -_tile() * 0.12)
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


# ── 7) 偏旁 / 组合技 ──────────────────────────────────

func _test_radicals_and_synergy() -> void:
	print("\n[7] 偏旁与组合技")
	await _clear_field()
	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	_check(lib != null and lib.radicals.size() >= 11, "偏旁库加载（%d 个字）"
		% (lib.radicals.size() if lib != null else 0))
	if lib == null:
		return

	var v0 := _player.vanish_factor
	RunState.add_radical(lib.find_by_id("mo_ri"))
	await get_tree().process_frame
	_check(_player.vanish_factor > v0, "「暮」让消失变慢")
	_check(_player.vision_factor < 1.0, "「暮」的副作用：视野变暗（%.2f）" % _player.vision_factor)

	# 组合技「暮慕」应该抵消视野惩罚
	RunState.add_radical(lib.find_by_id("mo_xin"))
	await get_tree().process_frame
	_check(absf(_player.vision_factor - 1.0) < 0.01,
		"组合技「暮慕」抵消了视野变暗（%.2f）" % _player.vision_factor)
	_check(_player.attract, "组合技保留磁吸")
	_check(_player.attract_radius_mul > 1.0, "磁吸范围被放大（x%.1f）" % _player.attract_radius_mul)

	# 漠：三发且无副作用
	RunState.radicals.clear()
	RunState.radicals.append(lib.find_by_id("mo_shui"))
	RunState.radicals_changed.emit()
	await get_tree().process_frame
	_check(absf(_player.vanish_factor - 1.0) < 0.01, "「漠」没有副作用")
	for c in _world.get_children():
		if c is InkShot:
			c.queue_free()
	await _wait_physics(3)
	_player.do_skill("skill_1")
	await _wait_physics(2)
	var shots := 0
	for c in _world.get_children():
		if c is InkShot:
			shots += 1
	_check(shots == 3, "「漠」一次打出三发水柱（%d 发）" % shots)

	# 「摸」主动技能：把金币抓过来
	RunState.radicals.clear()
	RunState.radicals.append(lib.find_by_id("mo_shou"))
	RunState.radicals_changed.emit()
	await get_tree().process_frame
	var coin := Coin.new()
	coin.setup(Assets.cfg.color_coin)
	coin.position = _player.position + Vector2(_tile() * 6.0, 0)
	_world.add_child(coin)
	await _wait_physics(3)
	var d0: float = coin.global_position.distance_to(_player.global_position)
	_player.do_skill("skill_2")
	await _wait_physics(3)
	var pulled := false
	if not is_instance_valid(coin):
		pulled = true      # 直接被吸进嘴里了
	else:
		pulled = coin.global_position.distance_to(_player.global_position) < d0 - 100.0
	_check(pulled, "「摸」把金币抓了过来（距离 %.0f）" % d0)

	# 「馍」立即回血
	RunState.radicals.clear()
	RunState.radicals_changed.emit()
	_player.revive_state()
	_player._invuln = 0.0
	_player.take_damage(1.5)
	var hp0 := _player.hp
	RadicalEffects.on_pickup(_player, lib.find_by_id("mo_shi"))
	await get_tree().process_frame
	_check(_player.hp > hp0, "「馍」立即回血")


# ── 8) 二段跳（永久特性）──────────────────────────────

func _test_double_jump() -> void:
	print("\n[8] 「蟆」的永久二段跳")
	await _clear_field()
	var had := MetaState.has_trait("double_jump")
	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	RunState.radicals.clear()
	RunState.radicals.append(lib.find_by_id("mo_chong"))
	RunState.radicals_changed.emit()
	await get_tree().process_frame
	_check(MetaState.has_trait("double_jump"), "拿到「蟆」就永久解锁二段跳（写进存档）")
	_check(_player.can_double_jump, "二段跳能力生效")

	await _place_on_column(_find_land(_pcx()))
	await _wait_physics(25)
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	var reached_falling := false
	for i in range(60):
		await get_tree().physics_frame
		if _player.velocity.y > 0.0:
			reached_falling = true
			break
	_check(reached_falling, "一段跳后开始下落")
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	_check(_player.velocity.y < -350.0, "空中再按跳跃触发二段跳（vy=%.0f）" % _player.velocity.y)

	# 「蟆」的永久特性不该被测试污染存档
	if not had:
		MetaState.traits.erase("double_jump")
		MetaState.save_game()
	RunState.radicals.clear()
	RunState.radicals_changed.emit()


# ── 9) 商店 ───────────────────────────────────────────

func _test_shop() -> void:
	print("\n[9] 商店")
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
	# 面板不能挡住主角（否则玩家看不见脚下在塌）
	var panel: ColorRect = _main.shop_ui._bg
	var vp := _player.get_viewport().get_visible_rect().size
	var player_screen: Vector2 = _player.get_viewport().get_canvas_transform() \
		* _player.global_position
	_check(not panel.get_rect().has_point(player_screen),
		"商店面板没有挡住主角（面板在右上角）")
	_main.shop_ui._try_buy(0)
	await get_tree().process_frame
	_check(_player.hp > hp0, "买「回心」回了血")
	_check(RunState.coins < coins0, "买完扣了金币")
	_main.shop_ui.close()
	await get_tree().process_frame
	_check(not _player.input_locked, "关店后恢复操作")


# ── 10) Boss「有」─────────────────────────────────────

func _test_boss() -> void:
	print("\n[10] Boss「有」")
	await _clear_field()
	await _place_on_column(_find_land(_pcx()))
	await _wait_physics(20)
	var boss := Boss.new()
	boss.setup(Balance.d, _player)
	boss.position = _player.global_position + Vector2(_tile() * 4.0, -_tile() * 1.5)
	boss._home = boss.position
	_world.add_child(boss)
	await _wait_physics(20)
	_check(boss.engaged, "进入范围后 Boss 开始交战")
	var hp0 := boss.hp
	boss.hit(5.0, Vector2.ZERO)
	await _wait_physics(2)
	_check(boss.hp < hp0, "Boss 会掉血（%.0f -> %.0f）" % [hp0, boss.hp])
	var souls0 := MetaState.souls
	boss.hit(999.0, Vector2.ZERO)
	await _wait_physics(4)
	_check(not is_instance_valid(boss) or boss.is_queued_for_deletion(), "Boss 会被击杀")
	_check(MetaState.souls > souls0, "击杀 Boss 给了魂币（%d -> %d）" % [souls0, MetaState.souls])


# ── 11) 梯子 ──────────────────────────────────────────

func _test_ladder() -> void:
	print("\n[11] 梯子（全作唯一能向上爬的东西）")
	await _clear_field()
	var s := _world.world_seed
	var spot := Vector2i(-99999, -99999)
	var k_found := 0
	for k in range(-4, 3):
		for si in range(-60, 61):
			var st := TerrainGen.struct_for_slot(si, k, s)
			if st == null or st.id != "ladder_tower":
				continue
			var ox := TerrainGen.struct_anchor_col(si, k, st.width(), s)
			if ox < 0:
				continue
			# 梯子在结构第 1 列，最下面一格
			spot = Vector2i(ox + 1, TerrainGen.struct_base_row(si, k, s) - 2)
			k_found = k
			break
		if spot.x > -99999:
			break
	_check(spot.x > -99999, "世界上能找到一座梯塔（列 %d 层带 %d）" % [spot.x, k_found])
	if spot.x <= -99999:
		return
	_check(TerrainGen.is_ladder(spot.x, spot.y, s), "那一格确实是梯子")
	# 把主角放到梯子下段，按住"上"看他会不会爬上去
	var t := float(_tile())
	_player.position = Vector2(spot.x * t + t * 0.5, spot.y * t + t * 0.5)
	_player.velocity = Vector2.ZERO
	await _wait_physics(4)
	var y0 := _player.global_position.y
	Input.action_press("move_up")
	await _wait_physics(35)
	Input.action_release("move_up")
	var climbed := y0 - _player.global_position.y
	_check(_player.climbing, "在梯子上进入爬梯状态")
	_check(climbed > t * 0.8, "确实向上爬了（%.1f px = %.2f 格）" % [climbed, climbed / t])
	# 按跳跃脱离
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await _wait_physics(3)
	_check(not _player.climbing, "按跳跃能脱离梯子")


# ── 12) 性能 ──────────────────────────────────────────

func _test_performance() -> void:
	print("\n[11] 性能：玩久了不该越来越卡")
	await _clear_field()
	var e0 := _world.entity_count()
	var n0 := _world.node_count()
	var cx := _pcx()
	for i in range(30):
		cx += 20
		_place_on_column(cx)
		await get_tree().process_frame
		await _wait_physics(3)
	var e1 := _world.entity_count()
	var n1 := _world.node_count()
	_check(e1 < 140, "出界实体被卸载，实体数有界（%d -> %d）" % [e0, e1])
	_check(n1 < 2000, "走过 600 格后节点数有界（%d -> %d）" % [n0, n1])


func _shoot() -> void:
	print("\n[12] 截图")
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
