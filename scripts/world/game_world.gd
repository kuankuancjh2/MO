class_name GameWorld
extends Node2D
## 世界管理器：围绕主角按需生成 / 卸载地块，并把「已消失的格子」记住。
##
## 生成是纯函数，所以卸载远处地块是安全的 —— 回头再看还是同一个地形。
## 但「被莫踩没了的格子」必须记在 _destroyed 里，否则重新加载会长回来 ——
## 这正是主题：莫走过的地方，永久地归于无。

const REFRESH_MARGIN := 3   ## 主角移动超过这么多格才重算一次，避免每帧抖动

var tile: int = 48
var cols: int = 24
var rows: int = 18
var world_seed: int = 1

var player: Node2D

var _tiles: Dictionary = {}      ## Vector2i -> SolidTile
var _destroyed: Dictionary = {}  ## Vector2i -> true
var _enemies: Dictionary = {}    ## Vector2i -> enemy
var _pickups: Dictionary = {}    ## Vector2i -> pickup
var _anchor := Vector2i(1 << 29, 1 << 29)


func _ready() -> void:
	var b := Balance.d
	tile = b.tile_size
	cols = b.world_cols
	rows = b.world_rows
	if b.fixed_world_seed != 0:
		world_seed = b.fixed_world_seed
	else:
		world_seed = randi()


## 每个新的一局调用：清空地形与「已消失」记录。
func reset_run(new_seed: bool = true) -> void:
	for t in _tiles.values():
		if is_instance_valid(t):
			t.queue_free()
	_tiles.clear()
	_destroyed.clear()
	for e in _enemies.values():
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	for p in _pickups.values():
		if is_instance_valid(p):
			p.queue_free()
	_pickups.clear()
	_anchor = Vector2i(1 << 29, 1 << 29)
	if new_seed:
		world_seed = randi()


func setup(p: Node2D) -> void:
	player = p
	_refresh(_cell(p.global_position))


## 出生点：站在第 0 层带的地面之上（该处地形被 TerrainGen 强制成安全区）。
func spawn_point() -> Vector2:
	return Vector2(tile * 0.5, -float(tile) * 0.6)


func notify_destroyed(cell: Vector2i) -> void:
	_destroyed[cell] = true
	_tiles.erase(cell)


## 已经被「莫」抹掉的格子数量（供测试与 UI 使用）
func destroyed_count() -> int:
	return _destroyed.size()


func tile_count() -> int:
	return _tiles.size()


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

	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var key := Vector2i(x, y)
			if _tiles.has(key) or _destroyed.has(key):
				continue
			if not TerrainGen.is_solid(x, y, world_seed):
				continue
			_spawn_tile(key)

	# 卸载远地块
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

	_spawn_entities(min_c, max_c, c)


func _spawn_tile(key: Vector2i) -> void:
	var t := SolidTile.new()
	t.setup(key, tile, self)
	add_child(t)
	_tiles[key] = t


## 敌人 / 偏旁的生成：与地形同样用确定性随机，避免卸载重载后消失或重复。
## 只在「离主角较远的最小圈层」生成，防止怪直接刷在脸上。
func _spawn_entities(min_c: Vector2i, max_c: Vector2i, center: Vector2i) -> void:
	var b := Balance.d
	for x in range(min_c.x, max_c.x + 1):
		var y := min_c.y
		while y <= max_c.y:
			var key := Vector2i(x, y)
			# 找一个可以站人的平台顶（上一格是空，本体是实心）
			if TerrainGen.is_solid(x, y, world_seed) and not TerrainGen.is_solid(x, y - 1, world_seed):
				var dist := absi(x - center.x) + absi(y - center.y)
				if dist > 8 and not _destroyed.has(key) and not _enemies.has(key) and not _pickups.has(key):
					var r := TerrainGen.rand01(x, y, world_seed + 555)
					if r < b.radical_spawn_chance:
						_spawn_pickup(Vector2i(x, y - 1))
					elif r < b.radical_spawn_chance + b.enemy_spawn_chance:
						_spawn_enemy(Vector2i(x, y - 1))
				y += TerrainGen.BAND_ROWS
			else:
				y += 1


func _spawn_enemy(cell: Vector2i) -> void:
	var e := RedBlock.new()
	e.setup(Balance.d)
	# 物理体要在入树前定位（见 main.gd 里的说明）
	e.position = Vector2(cell.x * tile + tile * 0.5, cell.y * tile + tile - 18.0)
	add_child(e)
	_enemies[cell] = e


func _spawn_pickup(cell: Vector2i) -> void:
	var lib: RadicalLibrary = _library()
	if lib == null or lib.radicals.is_empty():
		return
	var idx := int(TerrainGen.rand01(cell.x, cell.y, world_seed + 999) * lib.radicals.size())
	idx = clampi(idx, 0, lib.radicals.size() - 1)
	var p := RadicalPickup.new()
	p.setup(lib.radicals[idx], player)
	p.position = Vector2(cell.x * tile + tile * 0.5, cell.y * tile + tile * 0.5)
	add_child(p)
	_pickups[cell] = p


func _library() -> RadicalLibrary:
	if not ResourceLoader.exists("res://data/radical_library.tres"):
		return null
	return load("res://data/radical_library.tres") as RadicalLibrary
