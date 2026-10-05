class_name TerrainGen
extends RefCounted
## 无限地形生成器（任意方向延伸）。
##
## 结构：
##   层带 k   覆盖行 [k*BAND_ROWS, (k+1)*BAND_ROWS)   —— 每带一条厚 2 格的平台，其余为空
##   块       每 BLOCK_W 列一个块，块内平台高度统一（目的是让横向连贯）
##   结构     每 STRUCT_SPAN 列一个槽位，按概率嵌入一个手工设计的结构（小屋/小摊/高台）
##
## 关键约束（都是为了让地形「永远过得去」）：
##   * 相邻块台阶落差 <= 1 格 —— 一定跳得上去（跳跃高度 90px = 1.88 格）
##   * 洞宽 <= 3 格，且块的两端各留 >=1 格实地 —— 相邻块的洞不会连成深渊
##     （跳跃水平距离 173px = 3.6 格）
##   * 结构的「地面层」必须左右贯通（由 StructureData.ground_row_is_open 自检）
##
## is_solid 是纯函数：同样的 (cx, cy, seed) 永远同样结果 → 地块可以随便卸载重载。

const BAND_ROWS := 8          ## 每层带的行数 = 层与层的落差
const PLATFORM_THICK := 2     ## 平台厚度
const BLOCK_W := 11           ## 平台高度变化的粒度（列）—— 调大 = 平台更长更连贯
const RAISE_CHANCE := 0.25    ## 一个块比基准高 1 格的概率
const HOLE_CHANCE := 0.35     ## 一个块里开洞的概率（调低 = 横向更连贯）
const HOLE_MAX := 3           ## 洞最宽几格（必须 <= 可跳跃距离）
const ISLAND_CHANCE := 0.15   ## 层带中部出现浮岛的概率（掉下去的补救落脚点）
const SAFE_BLOCKS := 1        ## |bx| <= 此值的块在 0 层强制平坦无洞（出生安全区）

const STRUCT_SPAN := 34       ## 每隔多少列一个「结构槽位」
const STRUCT_MARGIN := 8      ## 结构离槽位左边界的距离
const STRUCT_CHANCE := 0.55   ## 一个槽位真的放结构的概率
const STRUCT_SAFE := 34       ## 结构整体离原点至少要有多远（避开出生点）

static var _structs: Array = []
static var _structs_loaded := false


# ── 基础工具 ───────────────────────────────────────────

## 地板除（GDScript 的 / 对负数朝零截断，这里要朝下取整）
static func fdiv(a: int, b: int) -> int:
	return floori(float(a) / float(b))


## 确定性伪随机：0.0 ~ 1.0
static func rand01(x: int, y: int, s: int) -> float:
	var h := hash(Vector3i(x, y, s))
	return float(absi(h) % 1000003) / 1000003.0


static func _is_safe(bx: int, k: int) -> bool:
	return k == 0 and absi(bx) <= SAFE_BLOCKS


# ── 平台 ───────────────────────────────────────────────

## 该块在层带内平台顶部的行偏移（0 或 1）
static func block_top(bx: int, k: int, s: int) -> int:
	if _is_safe(bx, k):
		return 0
	return 1 if rand01(bx, k * 31 + 7, s) < RAISE_CHANCE else 0


## 该块的洞：(起点, 宽度)。宽度 0 = 没洞。起点避开块两端，保证相邻洞之间隔 >=2 格。
static func block_hole(bx: int, k: int, s: int) -> Vector2i:
	if _is_safe(bx, k):
		return Vector2i(0, 0)
	if rand01(bx, k * 31 + 101, s) > HOLE_CHANCE:
		return Vector2i(0, 0)
	var r := rand01(bx, k * 31 + 103, s)
	var ln := 1 + int(r * r * float(HOLE_MAX))   # 平方一下 → 偏向窄洞
	ln = mini(ln, HOLE_MAX)
	var span := BLOCK_W - ln - 1
	if span < 1:
		return Vector2i(0, 0)
	var start := 1 + int(rand01(bx, k * 31 + 107, s) * float(span))
	return Vector2i(start, ln)


static func _island_x(bx: int, k: int, s: int) -> int:
	return bx * BLOCK_W + 1 + int(rand01(bx * 7 + 5, k * 31 + 203, s) * float(BLOCK_W - 3))


# ── 结构 ───────────────────────────────────────────────
# 这层被 is_solid 每格调用一次，所以刻意写得「零分配」：
# 库只 load 一次、候选结构只算一次、不构造临时数组。

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
	for s in _structs:
		total += maxf(s.weight, 0.001)
	if total <= 0.0:
		return null
	var t := clampf(r, 0.0, 0.9999) * total
	for s in _structs:
		t -= maxf(s.weight, 0.001)
		if t <= 0.0:
			return s
	return _structs[_structs.size() - 1]


## 某个结构槽位在某一层带里放的是什么结构（没有则 null）
static func struct_for_slot(si: int, k: int, s: int) -> StructureData:
	_ensure_structs()
	if _structs.is_empty():
		return null
	if rand01(si, k * 31 + 501, s) > STRUCT_CHANCE:
		return null
	var st := _pick_struct(rand01(si, k * 31 + 601, s))
	if st == null:
		return null
	var ox := si * STRUCT_SPAN + STRUCT_MARGIN
	# 结构不能压在出生点上
	if ox < STRUCT_SAFE and ox + st.width() > -STRUCT_SAFE:
		return null
	return st


## 这一格属于结构吗？返回该格字符（"" = 不属于，由普通地形接管）。
static func struct_cell(cx: int, cy: int, s: int) -> String:
	_ensure_structs()
	if _structs.is_empty():
		return ""
	var k := fdiv(cy, BAND_ROWS)
	var si := fdiv(cx - STRUCT_MARGIN, STRUCT_SPAN)
	var st := struct_for_slot(si, k, s)
	if st == null:
		st = struct_for_slot(si - 1, k, s)   # 结构可能跨界，所以要看前一个槽位
		if st == null:
			return ""
		si -= 1
	var ox := si * STRUCT_SPAN + STRUCT_MARGIN
	var col := cx - ox
	if col < 0 or col >= st.width():
		return ""
	var base_row := k * BAND_ROWS + block_top(fdiv(ox, BLOCK_W), k, s)
	var row := cy - base_row
	if row == 0:
		return "#"   # 地基：强制实心，保证结构不会因为地形开洞而悬空
	var gr := st.height() + row
	if gr < 0 or gr >= st.height():
		return ""
	var c := st.cell(col, gr)
	return "" if c == "." else c


## 结构原点的世界列（供 GameWorld 直接盖章结构，不用逐格问）
static func struct_origin_col(si: int) -> int:
	return si * STRUCT_SPAN + STRUCT_MARGIN


## 结构的地基行（平台顶行）
static func struct_base_row(si: int, k: int, s: int) -> int:
	return k * BAND_ROWS + block_top(fdiv(struct_origin_col(si), BLOCK_W), k, s)


# ── 总入口 ─────────────────────────────────────────────

static func is_solid(cx: int, cy: int, s: int) -> bool:
	# 结构优先
	var sc := struct_cell(cx, cy, s)
	if sc != "":
		return StructureData.SOLID_CHARS.contains(sc)

	var k := fdiv(cy, BAND_ROWS)
	var r := cy - k * BAND_ROWS
	var bx := fdiv(cx, BLOCK_W)
	var top := block_top(bx, k, s)

	if r >= top and r < top + PLATFORM_THICK:
		var h := block_hole(bx, k, s)
		if h.y > 0:
			var lx := cx - bx * BLOCK_W
			if lx >= h.x and lx < h.x + h.y:
				return false
		return true

	# 层带中部的浮岛
	if r >= 4 and r < 5 and top <= 1:
		if rand01(bx * 7 + 3, k * 31 + 202, s) < ISLAND_CHANCE:
			var ix := _island_x(bx, k, s)
			if cx == ix or cx == ix + 1:
				return true

	return false


## 玩家所在「层号」：地表为 0，越往下越大（y 轴向下为正）。
static func layer_of(py: float, tile: int) -> int:
	return fdiv(floori(py / float(tile)) + 1, BAND_ROWS)


## 该列在层带 k 上的平台顶行号（用于找落脚点）
static func platform_top_row(cx: int, k: int, s: int) -> int:
	return k * BAND_ROWS + block_top(fdiv(cx, BLOCK_W), k, s)
