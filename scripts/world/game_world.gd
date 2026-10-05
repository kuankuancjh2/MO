class_name GameWorld
extends Node2D
## 世界管理器：围绕主角按需生成 / 卸载，并记住「已经被莫抹掉的格子」。
##
## 生成是纯函数，所以卸载远处内容是安全的 —— 回头再看还是同一个地形。
## 但两类状态必须额外记住：
##   1. 被莫踩没 / 撞碎的格子（_destroyed）—— 否则卸载再加载会长回来
##   2. 已经生成过的实体所在格（_spawned）—— 否则卸载再加载会翻倍
##
## ★ 性能要点：**实体也必须按范围卸载**。
## 只卸载方块而不管敌人，会导致玩家一路向右时身后堆满永不释放的怪，
## 越玩越卡（重开一局就好）—— 这正是之前那个 bug。

const REFRESH_MARGIN := 3

var tile: int = 48
var cols: int = 24
var rows: int = 18
var world_seed: int = 1

var player: Node2D

var _tiles: Dictionary = {}      ## Vector2i -> SolidTile
var _destroyed: Dictionary = {}  ## Vector2i -> true（永久抹掉的格子）
var _spawned: Dictionary = {}    ## Vector2i -> Node（敌人 / 字块 / 商店）
var _anchor := Vector2i(1 << 29, 1 << 29)
var _lib: RadicalLibrary


func _ready() -> void:
	var b := Balance.d
	tile = b.tile_size
	cols = b.world_cols
	rows = b.world_rows
	if b.fixed_world_seed != 0:
		world_seed = b.fixed_world_seed
	else:
		world_seed = randi()
	if ResourceLoader.exists("res://data/radical_library.tres"):
		_lib = load("res://data/radical_library.tres") as RadicalLibrary


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


func setup(p: Node2D) -> void:
	player = p
	_refresh(_cell(p.global_position))


func spawn_point() -> Vector2:
	return Vector2(tile * 0.5, -float(tile) * 0.6)


# ── 查询接口（给测试和其它系统用）────────────────────

func notify_destroyed(cell: Vector2i) -> void:
	_destroyed[cell] = true
	_tiles.erase(cell)


func destroyed_count() -> int:
	return _destroyed.size()


func tile_count() -> int:
	return _tiles.size()


func entity_count() -> int:
	return _spawned.size()


## 世界里所有活着的节点数（性能回归测试用）
func node_count() -> int:
	return get_child_count()


## 「红土」效果：把某点附近的地基直接打碎（脚下崩塌）
func break_tiles_near(pos: Vector2, radius_cells: int) -> void:
	var c := _cell(pos)
	var feet := c.y + 1
	for dx in range(-radius_cells, radius_cells + 1):
		for dy in range(0, 2):   # 平台厚 2 格，两层都打掉才是真洞
			var key := Vector2i(c.x + dx, feet + dy)
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


# ── 主循环：按需加载 / 卸载 ───────────────────────────

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
			var t := SolidTile.new()
			t.setup(key, tile, self)
			add_child(t)
			_tiles[key] = t


## 结构：直接按「槽位 × 层带」盖章，不用逐格问
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
	# 网格最后一行对齐 base_row - 1（玩家身体行）：row = gr - height
	var base := TerrainGen.struct_base_row(si, k, world_seed)
	for gr in range(st.height()):
		var line: String = st.grid[gr]
		for col in range(line.length()):
			var ch := line[col]
			if ch == "." or ch == "#":
				continue
			var wx := ox + col
			var wy := base + gr - st.height()
			if wx < min_c.x or wx > max_c.x or wy < min_c.y or wy > max_c.y:
				continue
			_spawn_marker(Vector2i(wx, wy), ch)


## 平台顶上按低概率随机刷东西（密度是刻意压低的）
func _spawn_random(min_c: Vector2i, max_c: Vector2i, center: Vector2i) -> void:
	var b := Balance.d
	var k0 := TerrainGen.fdiv(min_c.y, TerrainGen.BAND_ROWS)
	var k1 := TerrainGen.fdiv(max_c.y, TerrainGen.BAND_ROWS)
	# 概率累加表：[上限, 标记字符]
	var table := [
		[b.word_block_spawn_chance, "W"],
		[b.word_block_spawn_chance + b.enemy_spawn_chance, "E"],
		[b.word_block_spawn_chance + b.enemy_spawn_chance + b.seeker_spawn_chance, "K"],
		[b.word_block_spawn_chance + b.enemy_spawn_chance + b.seeker_spawn_chance
			+ b.flyer_spawn_chance, "F"],
		[b.word_block_spawn_chance + b.enemy_spawn_chance + b.seeker_spawn_chance
			+ b.flyer_spawn_chance + b.radical_enemy_chance, "R"],
	]
	for x in range(min_c.x, max_c.x + 1):
		for k in range(k0, k1 + 1):
			var top := TerrainGen.platform_top_row(x, k, world_seed)
			if not TerrainGen.is_solid(x, top, world_seed):
				continue                       # 这一列在这个层带是洞
			var cell := Vector2i(x, top - 1)
			if cell.y < min_c.y or cell.y > max_c.y:
				continue
			if _destroyed.has(cell) or _spawned.has(cell):
				continue
			if absi(x - center.x) + absi(cell.y - center.y) <= b.spawn_min_distance:
				continue                       # 别刷在脸上
			var r := TerrainGen.rand01(x, top, world_seed + 555)
			for entry in table:
				if r < float(entry[0]):
					_spawn_marker(cell, String(entry[1]))
					break


# ── 实体生成 ───────────────────────────────────────────

func _spawn_marker(cell: Vector2i, ch: String) -> void:
	if _destroyed.has(cell) or _spawned.has(cell):
		return
	var node: Node2D = null
	var rest_on_floor := false
	match ch:
		"W":
			var d := _random_radical(cell, 11)
			if d == null:
				return
			var wb := WordBlock.new()
			wb.setup(cell, tile, self, d)
			wb.position = Vector2(cell.x * tile, cell.y * tile)   # 方块用左上角定位
			node = wb
		"E":
			var e := RedBlock.new()
			e.setup(Balance.d)
			node = e
			rest_on_floor = true
		"K":
			var kk := Seeker.new()
			kk.setup(Balance.d)
			node = kk
			rest_on_floor = true
		"F":
			var f := Flyer.new()
			f.setup(Balance.d)
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
	if node is StaticBody2D:
		pass                                   # WordBlock 自己已经定位好了
	else:
		node.position = Vector2(cell.x * tile + tile * 0.5,
			(cell.y + 1) * tile - 18.0 if rest_on_floor else cell.y * tile + tile * 0.5)
	add_child(node)
	_spawned[cell] = node


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

	# ★ 实体也要卸载。注意用「节点当前所在格」判断，因为敌人会走动；
	#   但 _spawned 的 key 保持为出生格不动 —— 否则旧格子会被判为"空"而重复刷怪。
	var drop2: Array = []
	for key in _spawned.keys():
		var n: Node = _spawned[key]
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			drop2.append(key)
			continue
		var nc := _cell((n as Node2D).global_position)
		if nc.x < min_c.x or nc.x > max_c.x or nc.y < min_c.y or nc.y > max_c.y:
			n.queue_free()
			drop2.append(key)
	for k in drop2:
		_spawned.erase(k)
