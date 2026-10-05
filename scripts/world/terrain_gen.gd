class_name TerrainGen
extends RefCounted
## 无限地形生成器（任意方向延伸）—— **岛屿 + 横向桥接**
##
## 算法（就是常见的「噪声切岛 + 只连接相邻岛」做法，不做寻路）：
##   1. 每层带用 1D fBm（多倍频值噪声）算一条「陆地场」，超过阈值就是陆地。
##      连续的陆地列 = 一座**岛**；岛与岛之间是缺口。
##   2. 每座岛的内部高度恒定（保证岛内没有需要跳的台阶）。
##   3. 相邻两座岛之间架**桥**：只要缺口宽度 <= MAX_BRIDGE_GAP 且
##      两边高度差在桥跨度内爬得上去（每列抬升 <= 1 格），就架一条细木板桥。
##   4. 架不了桥的缺口 = **断崖**：故意留的深渊，掉下去就到下一层（这是"失误"点）。
##      为保证玩家能一眼区分，缺口要么窄到能跳过去（<= 3 格），要么宽得像断崖（>= 8 格）。
##
## 结构：
##   层带 k   覆盖行 [k*BAND_ROWS, (k+1)*BAND_ROWS)
##   岛       厚 ISLAND_THICK 行（厚实，像岛）
##   桥       厚 1 行（薄木板，一眼看出是"连接器"）
##
## is_solid 是纯函数（同样的 cx, cy, seed 永远同样结果）→ 地块可随便卸载重载。
## 列信息有缓存（按列算一次，而不是按格算），所以几百格的地形生成也很快。

const BAND_ROWS := 8
const ISLAND_THICK := 3        ## 岛的厚度
const BRIDGE_THICK := 1        ## 桥的厚度
const SKY_ROWS := 3            ## 层带内至少留几行天空（保证层与层之间有落差）

const LAND_SCALE := 0.055      ## 陆地场频率：越小岛越大
const LAND_THRESHOLD := 0.40   ## 超过就是陆地（越低陆地越多、岛越大、缺口越少）
const ALT_SCALE := 0.021       ## 岛高度场的频率
## 岛高度档位：只做 2 档（0 / 1）。
## 关键原因：相邻岛的落差必须 <= 1 格，否则窄缺口处会出现"跳不过去又不够宽"的死点。
## 2 档 → 相邻岛落差 <= 1 → 任何 <= MAX_BRIDGE_GAP 的缺口都架得起桥。
const ALT_LEVELS := 2
const MAX_BRIDGE_GAP := 16     ## 缺口宽于此就不架桥（变断崖）
const SCAN_LIMIT := 20         ## 找相邻岛时最多左右回看多少列（要 >= MAX_BRIDGE_GAP + 余量）
const SAFE_COLS := 16          ## 0 层带 |cx| <= 此值强制是连续陆地（出生安全区，无缺口）

const RADICAL_BLOCK_CHANCE := 0.018   ## 地表方块里藏偏旁的概率

const STRUCT_SPAN := 34        ## 每隔多少列一个「结构槽位」
const STRUCT_MARGIN := 8       ## 结构离槽位左边界的距离
const STRUCT_CHANCE := 0.55    ## 一个槽位真的放结构的概率
const STRUCT_SAFE := 34        ## 结构整体离原点至少要有多远（避开出生点）
const STRUCT_MAX_ALT := 1      ## 只有高度 <= 此值的岛会放结构（免得顶穿上一层）

## 列信息缓存：Vector2i(cx, k) -> Vector3i(kind, surface_local_row, island_start_col)
##   kind: 0=天空(无地面) 1=岛 2=桥
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


## 1D 值噪声（平滑插值），0..1
static func _vnoise(x: float, s: int) -> float:
	var i := floori(x)
	var f := x - float(i)
	var a := rand01(i, 0, s)
	var b := rand01(i + 1, 0, s)
	var t := f * f * (3.0 - 2.0 * f)
	return lerpf(a, b, t)


## 1D fBm（3 个倍频），归一化到 0..1
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


# ── 岛屿 ───────────────────────────────────────────────

static func _in_safe_zone(cx: int, k: int) -> bool:
	return k == 0 and absi(cx) <= SAFE_COLS


static func is_land(cx: int, k: int, s: int) -> bool:
	if _in_safe_zone(cx, k):
		return true
	return fbm1(float(cx) * LAND_SCALE, s + k * 1013) > LAND_THRESHOLD


## 这一列所属岛屿的最左列（往回扫到不再是陆地为止）
static func _island_start(cx: int, k: int, s: int) -> int:
	var x := cx
	var guard := 0
	while guard < 400 and is_land(x - 1, k, s):
		x -= 1
		guard += 1
	return x


## 岛内高度（层带内的行偏移）—— 同一座岛恒定，保证岛内没有台阶
static func _island_surface_local(start: int, k: int, s: int) -> int:
	var alt := int(fbm1(float(start) * ALT_SCALE, s + k * 577) * float(ALT_LEVELS))
	return clampi(alt, 0, ALT_LEVELS - 1)


static func _thick(kind: int) -> int:
	return BRIDGE_THICK if kind == 2 else ISLAND_THICK


## 计算一列的信息（不查缓存）
static func _compute_column(cx: int, k: int, s: int) -> Vector3i:
	if is_land(cx, k, s):
		# 注意：出生安全区**不特殊处理高度** —— 它只是"保证是陆地"，
		# 高度跟着它所在的岛走。否则安全区边界会出现跳不上去的台阶。
		var start := _island_start(cx, k, s)
		return Vector3i(1, _island_surface_local(start, k, s), start)

	# 缺口：找左右最近的岛，看看能不能架桥
	# ⚠️ 哨兵值是 -1（没找到），不能用 `left < 0` 判断 —— 列坐标本身就是负数！
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
		return Vector3i(0, 0, 0)

	var gap := right - left - 1
	if gap > MAX_BRIDGE_GAP:
		return Vector3i(0, 0, 0)          # 太宽 -> 断崖（故意留的深渊）
	var sl := _island_surface_local(_island_start(left, k, s), k, s)
	var sr := _island_surface_local(_island_start(right, k, s), k, s)
	if absi(sl - sr) > gap:
		return Vector3i(0, 0, 0)          # 高度差太大，桥抬不上去 -> 断崖
	var t := float(cx - left) / float(right - left)
	var row := roundi(lerpf(float(sl), float(sr), t))
	return Vector3i(2, clampi(row, 0, BAND_ROWS - SKY_ROWS - BRIDGE_THICK), left)


## 带缓存的列查询（is_solid 每格都会调它，所以必须快）
static func column(cx: int, k: int, s: int) -> Vector3i:
	if s != _cache_seed:
		_col_cache.clear()
		_cache_seed = s
	var key := Vector2i(cx, k)
	var c: Variant = _col_cache.get(key)
	if c != null:
		return c
	if _col_cache.size() > 100000:
		_col_cache.clear()
	c = _compute_column(cx, k, s)
	_col_cache[key] = c
	return c


# ── 结构（同前，但锚点改成"岛的地表"）────────────────

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


## 结构所在的层带行（结构的第 0 行从这里往上算）
static func struct_base_row(si: int, k: int, s: int) -> int:
	var c := column(struct_origin_col(si), k, s)
	return k * BAND_ROWS + maxi(c.y, 0)


static func struct_for_slot(si: int, k: int, s: int) -> StructureData:
	_ensure_structs()
	if _structs.is_empty():
		return null
	# 结构只能落在岛上，而且要矮一点的岛（免得结构顶穿上一层）
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
	var base_row := struct_base_row(si, k, s)
	var row := cy - base_row
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
	var local := c.y
	return r >= local and r < local + _thick(c.x)


## 方块外观：0 = 岩石（岛），1 = 木板（桥）
static func tile_style(cx: int, cy: int, s: int) -> int:
	var k := fdiv(cy, BAND_ROWS)
	var c := column(cx, k, s)
	return 1 if c.x == 2 else 0


## 这一格是否"地块的最上面一行"（玩家踩的就是这一行）
static func is_surface(cx: int, cy: int, s: int) -> bool:
	var k := fdiv(cy, BAND_ROWS)
	var r := cy - k * BAND_ROWS
	var c := column(cx, k, s)
	return c.x != 0 and r == c.y


## 这一格里藏着一个偏旁吗？
static func has_radical(cx: int, cy: int, s: int) -> bool:
	if struct_cell(cx, cy, s) == "W":
		return true                                   # 结构里钉死的字
	if not is_surface(cx, cy, s):
		return false                                  # 只在"踩得到的那一层"藏
	return rand01(cx, cy, s + 4242) < RADICAL_BLOCK_CHANCE


## 玩家所在层号：地表为 0，越往下越大
static func layer_of(py: float, tile: int) -> int:
	return fdiv(floori(py / float(tile)) + 1, BAND_ROWS)


## 某列在层带 k 上的地表行号（找落脚点用；没地面则返回该层带的基行）
static func surface_row(cx: int, k: int, s: int) -> int:
	var c := column(cx, k, s)
	return k * BAND_ROWS + (c.y if c.x != 0 else 0)


static func kind_at(cx: int, k: int, s: int) -> int:
	return column(cx, k, s).x


## 诊断用：说明这一列为什么是岛 / 桥 / 空
static func debug_column(cx: int, k: int, s: int) -> String:
	if is_land(cx, k, s):
		var st := _island_start(cx, k, s)
		return "岛 start=%d alt=%d" % [st, _island_surface_local(st, k, s)]
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
	var sl := _island_surface_local(_island_start(left, k, s), k, s)
	var sr := _island_surface_local(_island_start(right, k, s), k, s)
	if absi(sl - sr) > gap:
		return "空（高度差 %d > 缺口 %d）" % [absi(sl - sr), gap]
	return "桥（缺口 %d，高度 %d->%d）" % [gap, sl, sr]
