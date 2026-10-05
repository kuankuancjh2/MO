class_name TerrainGen
extends RefCounted
## 无限地形生成器（任意方向延伸）—— **岛屿 + 横向桥接 + 厚地体 + 生物群系**
##
## 算法（噪声切岛 + 只连接相邻岛，不做寻路）：
##   1. 每层带用 1D fBm 值噪声算「陆地场」，超阈值即陆地；连续陆地列 = 一座岛。
##   2. 每座岛内部高度恒定（岛内没有要跳的台阶）。
##   3. 相邻岛之间架桥：缺口 <= MAX_BRIDGE_GAP 且高度差爬得上去就架。
##   4. 架不了的缺口 = 断崖（故意留的深渊，掉下去到下一层）。
##
## ★ 厚地体：岛不再是一条薄片，而是 THICK_MIN~THICK_MAX 行的实心岩体
##   （长岛更厚）。地表 1 行用群系的地表砖，内部用填充砖 —— 这就是"自动拼接"。
##   地体内部还会挖拱腔（视觉上像堤坝，纯装饰不改碰撞）。
##
## ★ 生物群系：低频噪声把横向空间切成 4 个材质区（草原/沙地/石城/遗迹），
##   只改图案和一点灰度，**地图保持黑白**。
##
## is_solid 是纯函数（同坐标同结果）→ 地块可随便卸载重载；列信息有缓存。

const BAND_ROWS := 10          ## 每层带的行数 = 层与层的落差
const THICK_MIN := 4           ## 岛最薄几行
const THICK_MAX := 6           ## 岛最厚几行
const BRIDGE_THICK := 1        ## 桥面只有 1 行（细木板）
const MIN_VOID_ROWS := 3       ## 层带内至少留几行空（保证掉得下去）

const LAND_SCALE := 0.055
const LAND_THRESHOLD := 0.40
const ALT_SCALE := 0.021
const ALT_LEVELS := 2          ## 岛高度只做 2 档 —— 保证相邻岛落差 <=1，缺口才架得起桥
const MAX_BRIDGE_GAP := 16
const SCAN_LIMIT := 20
const SAFE_COLS := 16          ## 0 层带 |cx| <= 此值强制连续陆地（出生安全区）

const BIOME_SCALE := 0.011     ## 群系区频率（越小每个区越长）
const RADICAL_BLOCK_CHANCE := 0.018

const STRUCT_SPAN := 34
const STRUCT_MARGIN := 8
const STRUCT_CHANCE := 0.62    ## 提高：以前太稀，地图上几乎看不到结构
const STRUCT_SAFE := 34
const STRUCT_MAX_ALT := 1

## 列信息缓存：Vector2i(cx,k) -> Vector4i(kind, surface_local_row, island_start, thick)
##   kind: 0=天空 1=岛 2=桥
static var _col_cache: Dictionary = {}
static var _cache_seed: int = -2147483647
static var _structs: Array = []
static var _structs_loaded := false


# ── 噪声 ───────────────────────────────────────────────

static func fdiv(a: int, b: int) -> int:
	return floori(float(a) / float(b))


static func rand01(x: int, y: int, s: int) -> float:
	var h := hash(Vector3i(x, y, s))
	return float(absi(h) % 1000003) / 1000003.0


static func _vnoise(x: float, s: int) -> float:
	var i := floori(x)
	var f := x - float(i)
	var a := rand01(i, 0, s)
	var b := rand01(i + 1, 0, s)
	var t := f * f * (3.0 - 2.0 * f)
	return lerpf(a, b, t)


static func fbm1(x: float, s: int) -> float:
	var v := 0.0
	var amp := 0.5
	var freq := 1.0
	for o in range(3):
		v += _vnoise(x * freq, s + o * 7919) * amp
		amp *= 0.5
		freq *= 2.0
	return v / 0.875


static func clear_cache() -> void:
	_col_cache.clear()


# ── 生物群系 ───────────────────────────────────────────

static func biome_at(cx: int, s: int) -> int:
	var v := fbm1(float(cx) * BIOME_SCALE, s + 909)
	# fbm 值集中在 0.5 附近，先拉开一点再切档，免得总落在中间两档
	v = clampf((v - 0.28) / 0.44, 0.0, 0.9999)
	return int(v * float(BiomeTable.count()))


# ── 岛屿 ───────────────────────────────────────────────

static func _in_safe_zone(cx: int, k: int) -> bool:
	return k == 0 and absi(cx) <= SAFE_COLS


static func is_land(cx: int, k: int, s: int) -> bool:
	if _in_safe_zone(cx, k):
		return true
	return fbm1(float(cx) * LAND_SCALE, s + k * 1013) > LAND_THRESHOLD


static func _island_start(cx: int, k: int, s: int) -> int:
	var x := cx
	var guard := 0
	while guard < 400 and is_land(x - 1, k, s):
		x -= 1
		guard += 1
	return x


static func _island_end(cx: int, k: int, s: int) -> int:
	var x := cx
	var guard := 0
	while guard < 400 and is_land(x + 1, k, s):
		x += 1
		guard += 1
	return x


## 岛内高度（层带内的行偏移）—— 同一座岛恒定
static func _island_surface_local(start: int, k: int, s: int) -> int:
	var alt := int(fbm1(float(start) * ALT_SCALE, s + k * 577) * float(ALT_LEVELS))
	return clampi(alt, 0, ALT_LEVELS - 1)


## 岛的厚度：越长的岛越厚（"地体做厚"）
static func _island_thick(start: int, end: int, surface: int) -> int:
	var t := THICK_MIN + (end - start) / 14
	t = clampi(t, THICK_MIN, THICK_MAX)
	# 保证层带里还留得下 MIN_VOID_ROWS 行空
	return mini(t, BAND_ROWS - surface - MIN_VOID_ROWS)


static func _thick_of(kind: int, cached_thick: int) -> int:
	return BRIDGE_THICK if kind == 2 else cached_thick


## 计算一列（不查缓存）
static func _compute_column(cx: int, k: int, s: int) -> Vector4i:
	if is_land(cx, k, s):
		var start := _island_start(cx, k, s)
		var surf := _island_surface_local(start, k, s)
		var th := _island_thick(start, _island_end(cx, k, s), surf)
		return Vector4i(1, surf, start, th)

	# 缺口：找左右最近的岛，看能不能架桥
	# ⚠️ 哨兵是 -1（没找到），不能用 `< 0` 判断 —— 列坐标本身就是负数！
	var left := -1
	for d in range(1, SCAN_LIMIT + 1):
		if is_land(cx - d, k, s):
			left = cx - d
			break
	var right := -1
	for d in range(1, SCAN_LIMIT + 1):
		if is_land(cx + d, k, s):
			right = cx + d
			break
	if left == -1 or right == -1:
		return Vector4i(0, 0, 0, 0)
	var gap := right - left - 1
	if gap > MAX_BRIDGE_GAP:
		return Vector4i(0, 0, 0, 0)
	var ls := _island_start(left, k, s)
	var rs := _island_start(right, k, s)
	var sl := _island_surface_local(ls, k, s)
	var sr := _island_surface_local(rs, k, s)
	if absi(sl - sr) > gap:
		return Vector4i(0, 0, 0, 0)
	var t := float(cx - left) / float(right - left)
	var row := clampi(roundi(lerpf(float(sl), float(sr), t)), 0,
		BAND_ROWS - MIN_VOID_ROWS - BRIDGE_THICK)
	return Vector4i(2, row, left, BRIDGE_THICK)


## 带缓存的列查询（is_solid 每格都调它，必须快）
static func column(cx: int, k: int, s: int) -> Vector4i:
	if s != _cache_seed:
		_col_cache.clear()
		_cache_seed = s
	var key := Vector2i(cx, k)
	var c: Variant = _col_cache.get(key)
	if c != null:
		return c
	if _col_cache.size() > 120000:
		_col_cache.clear()
	c = _compute_column(cx, k, s)
	_col_cache[key] = c
	return c


# ── 结构 ───────────────────────────────────────────────

static func _ensure_structs() -> void:
	if _structs_loaded:
		return
	_structs_loaded = true
	if ResourceLoader.exists("res://data/structure_library.tres"):
		var lib := load("res://data/structure_library.tres") as StructureLibrary
		if lib != null:
			_structs = lib.usable_list()


static func _pick_struct(r: float) -> StructureData:
	var total := 0.0
	for st in _structs:
		total += maxf(st.weight, 0.001)
	if total <= 0.0:
		return null
	var t := clampf(r, 0.0, 0.9999) * total
	for st in _structs:
		t -= maxf(st.weight, 0.001)
		if t <= 0.0:
			return st
	return _structs[_structs.size() - 1]


static func struct_origin_col(si: int) -> int:
	return si * STRUCT_SPAN + STRUCT_MARGIN


static func struct_base_row(si: int, k: int, s: int) -> int:
	return k * BAND_ROWS + maxi(column(struct_origin_col(si), k, s).y, 0)


static func struct_for_slot(si: int, k: int, s: int) -> StructureData:
	_ensure_structs()
	if _structs.is_empty():
		return null
	var ox := struct_origin_col(si)
	var c := column(ox, k, s)
	if c.x != 1 or c.y > STRUCT_MAX_ALT:
		return null
	if rand01(si, k * 31 + 501, s) > STRUCT_CHANCE:
		return null
	var st := _pick_struct(rand01(si, k * 31 + 601, s))
	if st == null:
		return null
	if ox < STRUCT_SAFE and ox + st.width() > -STRUCT_SAFE:
		return null
	return st


static func struct_cell(cx: int, cy: int, s: int) -> String:
	_ensure_structs()
	if _structs.is_empty():
		return ""
	var k := fdiv(cy, BAND_ROWS)
	var si := fdiv(cx - STRUCT_MARGIN, STRUCT_SPAN)
	var st := struct_for_slot(si, k, s)
	if st == null:
		st = struct_for_slot(si - 1, k, s)
		if st == null:
			return ""
		si -= 1
	var ox := struct_origin_col(si)
	var col := cx - ox
	if col < 0 or col >= st.width():
		return ""
	var row := cy - struct_base_row(si, k, s)
	if row == 0:
		return "#"
	var gr := st.height() + row
	if gr < 0 or gr >= st.height():
		return ""
	var c := st.cell(col, gr)
	return "" if c == "." else c


# ── 总入口 ─────────────────────────────────────────────

static func is_solid(cx: int, cy: int, s: int) -> bool:
	var sc := struct_cell(cx, cy, s)
	if sc != "":
		return StructureData.SOLID_CHARS.contains(sc)
	var k := fdiv(cy, BAND_ROWS)
	var r := cy - k * BAND_ROWS
	var c := column(cx, k, s)
	if c.x == 0:
		return false
	return r >= c.y and r < c.y + _thick_of(c.x, c.w)


## 是不是「地表那一行」（用群系的地表砖）
static func is_surface(cx: int, cy: int, s: int) -> bool:
	var k := fdiv(cy, BAND_ROWS)
	var r := cy - k * BAND_ROWS
	var c := column(cx, k, s)
	return c.x != 0 and r == c.y


## 是不是「地体最底那一行」（用倒过来的地表砖收口）
static func is_bottom(cx: int, cy: int, s: int) -> bool:
	var k := fdiv(cy, BAND_ROWS)
	var r := cy - k * BAND_ROWS
	var c := column(cx, k, s)
	if c.x == 0:
		return false
	return r == c.y + _thick_of(c.x, c.w) - 1


## 这一格该用哪张素材（自动拼接的核心：地表/内部/桥）
static func art_for(cx: int, cy: int, s: int) -> String:
	var k := fdiv(cy, BAND_ROWS)
	var c := column(cx, k, s)
	if c.x == 2:
		return "tile_bridge"
	if c.x == 1:
		var b := biome_at(cx, s)
		if is_surface(cx, cy, s):
			return BiomeTable.surface_tex(b)
		return BiomeTable.fill_tex(b)
	var sc := struct_cell(cx, cy, s)
	if sc == "W" or sc == "#":
		var b2 := biome_at(cx, s)
		return BiomeTable.surface_tex(b2)
	return "tile_stone"


## 方块外观代号：0 = 岩石（岛），1 = 木板（桥）
static func tile_style(cx: int, cy: int, s: int) -> int:
	return 1 if kind_at(cx, fdiv(cy, BAND_ROWS), s) == 2 else 0


## 这一格里藏着一个偏旁吗？
static func has_radical(cx: int, cy: int, s: int) -> bool:
	if struct_cell(cx, cy, s) == "W":
		return true
	if not is_surface(cx, cy, s):
		return false
	return rand01(cx, cy, s + 4242) < RADICAL_BLOCK_CHANCE


## 玩家所在层号：地表为 0，越往下越大
static func layer_of(py: float, tile: int) -> int:
	return fdiv(floori(py / float(tile)) + 1, BAND_ROWS)


## 某列在层带 k 上的地表行号
static func surface_row(cx: int, k: int, s: int) -> int:
	var c := column(cx, k, s)
	return k * BAND_ROWS + (c.y if c.x != 0 else 0)


static func kind_at(cx: int, k: int, s: int) -> int:
	return column(cx, k, s).x


## 装饰：这一列地表上长什么（"" = 不长）。确定性随机 → 卸载重载不会跳。
static func deco_at(cx: int, k: int, s: int) -> String:
	var c := column(cx, k, s)
	if c.x == 0:
		return ""
	var b := biome_at(cx, s)
	if rand01(cx, k * 31 + 1701, s) > BiomeTable.deco_chance(b):
		return ""
	var list: Array = BiomeTable.deco(b)
	if list.is_empty():
		return ""
	return String(list[int(rand01(cx, k * 31 + 1801, s) * float(list.size())) % list.size()])


## 地体内部是否有拱腔（纯视觉：让厚地体看起来像有构造的堤坝）
static func arch_at(cx: int, cy: int, s: int) -> bool:
	var k := fdiv(cy, BAND_ROWS)
	var r := cy - k * BAND_ROWS
	var c := column(cx, k, s)
	if c.x != 1:
		return false
	var th: int = c.w
	if th < THICK_MIN + 1:
		return false
	# 只在厚地体的「底部 2 行」里、且成段出现（每段 3 列一拱）
	if r < c.y + th - 2:
		return false
	var bx := fdiv(cx, 3)
	if rand01(bx, k * 31 + 2201, s) > 0.55:
		return false
	# 3 列一个拱：中间那列挖空
	return (cx - bx * 3) == 1


## 调试用：说明这一列为什么是岛 / 桥 / 空
static func debug_column(cx: int, k: int, s: int) -> String:
	if is_land(cx, k, s):
		var st := _island_start(cx, k, s)
		return "岛 start=%d alt=%d thick=%d biome=%s" % [st, _island_surface_local(st, k, s),
			column(cx, k, s).w, BiomeTable.name_of(biome_at(cx, s))]
	var left := -1
	for d in range(1, SCAN_LIMIT + 1):
		if is_land(cx - d, k, s):
			left = cx - d
			break
	var right := -1
	for d in range(1, SCAN_LIMIT + 1):
		if is_land(cx + d, k, s):
			right = cx + d
			break
	if left == -1 or right == -1:
		return "空（找不到岛 left=%d right=%d）" % [left, right]
	var gap := right - left - 1
	if gap > MAX_BRIDGE_GAP:
		return "空（缺口 %d > 上限 %d）" % [gap, MAX_BRIDGE_GAP]
	return "桥（缺口 %d）" % gap
