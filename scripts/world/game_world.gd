class_name GameWorld
extends Node2D
## 世界管理器：围绕主角按需生成 / 卸载，并记住「已经被莫抹掉的格子」。
##
## 生成是纯函数，所以卸载远处内容是安全的。
## 但两类状态必须额外记住：
##   1. 被莫踩没 / 撞碎的格子（_destroyed）—— 否则卸载再加载会长回来
##   2. 已经生成过的实体所在格（_spawned）—— 否则卸载再加载会翻倍
##
## ★ 性能要点：**实体也必须按范围卸载**。只卸载方块而不管敌人，
## 会导致越玩越卡（重开一局就好）—— 这正是之前那个 bug。

const REFRESH_MARGIN := 3

var tile: int = 48
var cols: int = 24
var rows: int = 18
var world_seed: int = 1

var player: Node2D

var _tiles: Dictionary = {}      ## Vector2i -> SolidTile
var _destroyed: Dictionary = {}  ## Vector2i -> true（永久抹掉的格子）
var _spawned: Dictionary = {}    ## Vector2i -> Node（敌人 / 商店 / boss）
var _anchor := Vector2i(1 << 29, 1 << 29)
var _lib: RadicalLibrary
var _deco: DecoLayer
var _bg: BgParallax


func _ready() -> void:
	var b := Balance.d
	tile = b.tile_size
	cols = b.world_cols
	rows = b.world_rows
	if b.fixed_world_seed != 0:
		world_seed = b.fixed_world_seed
	else:
		world_seed = randi()
	TerrainGen.clear_cache()
	if ResourceLoader.exists("res://data/radical_library.tres"):
		_lib = load("res://data/radical_library.tres") as RadicalLibrary
	# 视差背景（在最后面）与装饰层（在地形之上、角色之下）
	_bg = BgParallax.new()
	add_child(_bg)
	_deco = DecoLayer.new()
	add_child(_deco)
	_deco.setup(self)


func reset_run(new_seed: bool = true) -> void:
	for t in _tiles.values():
		if is_instance_valid(t):
			t.queue_free()
	_tiles.clear()
	_destroyed.clear()
	for n in _spawned.values():
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	_anchor = Vector2i(1 << 29, 1 << 29)
	if new_seed:
		world_seed = randi()
		TerrainGen.clear_cache()


func setup(p: Node2D) -> void:
	player = p
	_refresh(_cell(p.global_position))


## 出生点：站在出生列的地表之上（0 层带 ±16 列被强制成连续陆地）
func spawn_point() -> Vector2:
	var row := TerrainGen.surface_row(0, 0, world_seed)
	return Vector2(tile * 0.5, row * tile - float(tile) * 0.6)


# ── 查询接口 ───────────────────────────────────────────

func notify_destroyed(cell: Vector2i) -> void:
	_destroyed[cell] = true
	_tiles.erase(cell)


## 某个实体被"消耗掉"（怪被打死 / 字块被撞碎）：
## 把它的出生格标记为永久消失，否则过几格回来会原地重生 —— 无限刷怪。
func consume_cell(node: Node) -> void:
	if node == null or not node.has_meta("spawn_cell"):
		return
	var cell: Vector2i = node.get_meta("spawn_cell")
	_destroyed[cell] = true
	_tiles.erase(cell)
	_spawned.erase(cell)


func destroyed_count() -> int:
	return _destroyed.size()


func tile_count() -> int:
	return _tiles.size()


func entity_count() -> int:
	return _spawned.size()


## 这一格是不是已经被莫永久抹掉了（装饰层用它判断"这里不再长东西"）
func is_destroyed(cell: Vector2i) -> bool:
	return _destroyed.has(cell)


func node_count() -> int:
	return get_child_count()


## 「红土」效果：把某点附近的地基直接打碎（脚下崩塌）
func break_tiles_near(pos: Vector2, radius_cells: int) -> void:
	var c := _cell(pos)
	for dx in range(-radius_cells, radius_cells + 1):
		for dy in range(0, 3):
			var key := Vector2i(c.x + dx, c.y + 1 + dy)
			if not _tiles.has(key):
				continue
			var t: Node = _tiles[key]
			_destroyed[key] = true
			_tiles.erase(key)
			if is_instance_valid(t):
				var burst := ShardBurst.new()
				burst.setup((t as Node2D).position + Vector2(tile, tile) * 0.5,
					Assets.cfg.color_tile_warn, 7, 5.0, 140.0)
				add_child(burst)
				t.queue_free()


## Boss「有」的造物：凭空造出一块临时方块。
## 被莫碰过之后它照样会消失 —— 这就是"有"和"莫"的对抗。
func spawn_temp_tile(cell: Vector2i) -> bool:
	if _tiles.has(cell) or _destroyed.has(cell):
		return false
	if not _in_loaded_rect(cell):
		return false
	var t := SolidTile.new()
	t.setup(cell, tile, self, 0, null)
	add_child(t)
	_tiles[cell] = t
	return true


func _in_loaded_rect(cell: Vector2i) -> bool:
	var min_c := Vector2i(_anchor.x - cols, _anchor.y - rows)
	var max_c := Vector2i(_anchor.x + cols, _anchor.y + rows)
	return cell.x >= min_c.x and cell.x <= max_c.x and cell.y >= min_c.y and cell.y <= max_c.y


# ── 主循环 ─────────────────────────────────────────────

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(tile)), floori(pos.y / float(tile)))


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var c := _cell(player.global_position)
	if absi(c.x - _anchor.x) > REFRESH_MARGIN or absi(c.y - _anchor.y) > REFRESH_MARGIN:
		_refresh(c)


func _refresh(c: Vector2i) -> void:
	_anchor = c
	var min_c := Vector2i(c.x - cols, c.y - rows)
	var max_c := Vector2i(c.x + cols, c.y + rows)
	_spawn_tiles(min_c, max_c)
	_spawn_structures(min_c, max_c)
	_spawn_random(min_c, max_c, c)
	_unload(min_c, max_c)


func _spawn_tiles(min_c: Vector2i, max_c: Vector2i) -> void:
	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var key := Vector2i(x, y)
			if _tiles.has(key) or _destroyed.has(key):
				continue
			if not TerrainGen.is_solid(x, y, world_seed):
				continue
			var style := TerrainGen.tile_style(x, y, world_seed)
			var rad: RadicalData = null
			if TerrainGen.has_radical(x, y, world_seed):
				rad = _random_radical(key, 11 + style)
			var t := SolidTile.new()
			t.setup(key, tile, self, style, rad,
				TerrainGen.art_for(x, y, world_seed),
				TerrainGen.arch_at(x, y, world_seed),
				TerrainGen.is_bottom(x, y, world_seed),
				TerrainGen.biome_at(x, world_seed))
			add_child(t)
			_tiles[key] = t


## 结构：直接按「槽位 × 层带」盖章
func _spawn_structures(min_c: Vector2i, max_c: Vector2i) -> void:
	var si0 := TerrainGen.fdiv(min_c.x - TerrainGen.STRUCT_MARGIN, TerrainGen.STRUCT_SPAN)
	var si1 := TerrainGen.fdiv(max_c.x - TerrainGen.STRUCT_MARGIN, TerrainGen.STRUCT_SPAN)
	var k0 := TerrainGen.fdiv(min_c.y, TerrainGen.BAND_ROWS)
	var k1 := TerrainGen.fdiv(max_c.y, TerrainGen.BAND_ROWS)
	for si in range(si0, si1 + 1):
		for k in range(k0, k1 + 1):
			var st := TerrainGen.struct_for_slot(si, k, world_seed)
			if st == null:
				continue
			_stamp_structure(st, si, k, min_c, max_c)


func _stamp_structure(st: StructureData, si: int, k: int, min_c: Vector2i, max_c: Vector2i) -> void:
	var ox := TerrainGen.struct_origin_col(si)
	var base := TerrainGen.struct_base_row(si, k, world_seed)
	for gr in range(st.height()):
		var line: String = st.grid[gr]
		for col in range(line.length()):
			var ch := line[col]
			# '#' 和 'W' 由地形层生成为 SolidTile（W 是"里面藏了偏旁"的方块）
			if ch == "." or ch == "#" or ch == "W":
				continue
			var wx := ox + col
			var wy := base + gr - st.height()
			if wx < min_c.x or wx > max_c.x or wy < min_c.y or wy > max_c.y:
				continue
			_spawn_marker(Vector2i(wx, wy), ch)


## 平台/地表上按低概率随机刷怪（密度刻意压低）
func _spawn_random(min_c: Vector2i, max_c: Vector2i, center: Vector2i) -> void:
	var b := Balance.d
	var k0 := TerrainGen.fdiv(min_c.y, TerrainGen.BAND_ROWS)
	var k1 := TerrainGen.fdiv(max_c.y, TerrainGen.BAND_ROWS)
	var table := [
		[b.enemy_spawn_chance, "E"],
		[b.enemy_spawn_chance + b.seeker_spawn_chance, "K"],
		[b.enemy_spawn_chance + b.seeker_spawn_chance + b.flyer_spawn_chance, "F"],
		[b.enemy_spawn_chance + b.seeker_spawn_chance + b.flyer_spawn_chance
			+ b.radical_enemy_chance, "R"],
	]
	for x in range(min_c.x, max_c.x + 1):
		for k in range(k0, k1 + 1):
			# 站人的那一格 = 地表上面那格
			var surf := TerrainGen.surface_row(x, k, world_seed)
			var cell := Vector2i(x, surf - 1)
			if cell.y < min_c.y or cell.y > max_c.y:
				continue
			if _destroyed.has(cell) or _spawned.has(cell):
				continue
			if absi(x - center.x) + absi(cell.y - center.y) <= b.spawn_min_distance:
				continue
			var r := TerrainGen.rand01(x, surf, world_seed + 555)
			for entry in table:
				if r < float(entry[0]):
					_spawn_marker(cell, String(entry[1]))
					break


# ── 实体生成 ───────────────────────────────────────────

func _spawn_marker(cell: Vector2i, ch: String) -> void:
	if _destroyed.has(cell) or _spawned.has(cell):
		return
	if ch == "B":
		_spawn_boss(cell)
		return
	var node: Node2D = null
	var rest_on_floor := false
	var word_r := TerrainGen.rand01(cell.x, cell.y, world_seed + 3301)
	match ch:
		"E":
			var e := RedBlock.new()
			e.setup(Balance.d)
			e.apply_word(WordEnemyTable.pick("walk", word_r))
			node = e
			rest_on_floor = true
		"K":
			var kk := Seeker.new()
			kk.setup(Balance.d)
			kk.apply_word(WordEnemyTable.pick("chase", word_r))
			node = kk
			rest_on_floor = true
		"F":
			var f := Flyer.new()
			f.setup(Balance.d)
			f.apply_word(WordEnemyTable.pick("fly", word_r))
			node = f
		"R":
			var r := RadicalEnemy.new()
			r.setup(Balance.d, int(TerrainGen.rand01(cell.x, cell.y, world_seed + 71) * 4.0))
			node = r
		"S":
			var s := Shop.new()
			s.setup(player)
			node = s
		_:
			return
	if node == null:
		return
	# 注意：不能用 `node is StaticBody2D` 来区分 —— AnimatableBody2D 也继承自它。
	node.position = Vector2(cell.x * tile + tile * 0.5,
		(cell.y + 1) * tile - 18.0 if rest_on_floor else cell.y * tile + tile * 0.5)
	add_child(node)
	node.set_meta("spawn_cell", cell)
	_spawned[cell] = node


func _spawn_boss(cell: Vector2i) -> void:
	var boss := Boss.new()
	boss.setup(Balance.d, player)
	boss.position = Vector2(cell.x * tile + tile * 0.5, (cell.y + 1) * tile - 60.0)
	add_child(boss)
	boss.set_meta("spawn_cell", cell)
	_spawned[cell] = boss


func _random_radical(cell: Vector2i, salt: int) -> RadicalData:
	if _lib == null or _lib.radicals.is_empty():
		return null
	var i := int(TerrainGen.rand01(cell.x, cell.y, world_seed + salt) * _lib.radicals.size())
	return _lib.radicals[clampi(i, 0, _lib.radicals.size() - 1)]


# ── 卸载 ───────────────────────────────────────────────

func _unload(min_c: Vector2i, max_c: Vector2i) -> void:
	var drop: Array = []
	for key in _tiles.keys():
		var k: Vector2i = key
		if k.x < min_c.x or k.x > max_c.x or k.y < min_c.y or k.y > max_c.y:
			drop.append(k)
	for k in drop:
		var t: Node = _tiles[k]
		if is_instance_valid(t):
			t.queue_free()
		_tiles.erase(k)

	# ★ 实体也要卸载。用「节点当前所在格」判断（敌人会走动），
	#   但 _spawned 的 key 保持为出生格不动 —— 否则旧格子会被判为"空"而重复刷怪。
	#   这里必须用无类型变量接字典的值：条目可能指向已释放的实例。
	var drop2: Array = []
	for key in _spawned.keys():
		var n = _spawned[key]
		if n == null or not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
			drop2.append(key)
			continue
		if (n as Node).is_in_group("boss") and (n as Boss).engaged:
			continue                       # Boss 一旦开打就不随镜头卸载
		var nc := _cell((n as Node2D).global_position)
		if nc.x < min_c.x or nc.x > max_c.x or nc.y < min_c.y or nc.y > max_c.y:
			(n as Node).queue_free()
			drop2.append(key)
	for k in drop2:
		_spawned.erase(k)
