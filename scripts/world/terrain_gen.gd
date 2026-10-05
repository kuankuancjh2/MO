class_name TerrainGen
extends RefCounted
## 无限地形生成器（任意方向延伸）。
##
## 结构：世界被水平切成「层带」（band），每带高 BAND_ROWS 格；层带之间是空的。
##   层带 k 覆盖行 [k*BAND_ROWS, (k+1)*BAND_ROWS)
## 每层带里有一条平台（厚 PLATFORM_THICK），从洞里掉下去 = 落到下一层继续打。
##
## 关键约束（都是为了让地形「永远过得去」）：
##   * 平台高度以「块」（BLOCK_W 列）为单位变化，落差最多 1 格 —— 一定跳得上去。
##   * 洞的宽度最多 3 格，且块的两端各留至少 1 格实地 —— 相邻块的洞不会连成深渊。
##   * 跳跃水平距离约 173px（3.6 格），所以 3 格洞刚好跳得过去。
##
## 生成是「纯函数」：同样的 (cx, cy, seed) 永远得到同样结果，
## 所以远处地块可以随便卸载，回头看还是一模一样。

const BAND_ROWS := 8          ## 每层带的行数 = 层与层的落差
const PLATFORM_THICK := 2     ## 平台厚度
const BLOCK_W := 7            ## 平台高度变化的粒度（列）
const RAISE_CHANCE := 0.32    ## 一个块比基准高 1 格的概率
const HOLE_CHANCE := 0.55     ## 一个块里开洞的概率
const HOLE_MAX := 3           ## 洞最宽几格（必须 <= 可跳跃距离）
const ISLAND_CHANCE := 0.22   ## 层带中部出现浮岛的概率
const SAFE_BLOCKS := 1        ## |bx| <= 此值的块在 0 层强制平坦无洞（出生安全区）


## 地板除（GDScript 的 / 对负数朝零截断，这里要朝下取整）
static func fdiv(a: int, b: int) -> int:
	return floori(float(a) / float(b))


## 确定性伪随机：0.0 ~ 1.0
static func rand01(x: int, y: int, s: int) -> float:
	var h := hash(Vector3i(x, y, s))
	return float(absi(h) % 1000003) / 1000003.0


static func _is_safe(bx: int, k: int) -> bool:
	return k == 0 and absi(bx) <= SAFE_BLOCKS


## 该块在层带内平台顶部的行偏移（0 或 1）
static func block_top(bx: int, k: int, s: int) -> int:
	if _is_safe(bx, k):
		return 0
	return 1 if rand01(bx, k * 31 + 7, s) < RAISE_CHANCE else 0


## 该块的洞：(起点, 宽度)。宽度 0 = 没洞。
## 起点会避开块的两端，保证相邻块的洞之间至少有 2 格实地。
static func block_hole(bx: int, k: int, s: int) -> Vector2i:
	if _is_safe(bx, k):
		return Vector2i(0, 0)
	if rand01(bx, k * 31 + 101, s) > HOLE_CHANCE:
		return Vector2i(0, 0)
	var ln := 1 + int(rand01(bx, k * 31 + 103, s) * float(HOLE_MAX))
	ln = mini(ln, HOLE_MAX)
	var span := BLOCK_W - ln - 1
	if span < 1:
		return Vector2i(0, 0)
	var start := 1 + int(rand01(bx, k * 31 + 107, s) * float(span))
	return Vector2i(start, ln)


## 浮岛：层带中部飘着的一小块落脚点（宽 2 格）
static func _island_x(bx: int, k: int, s: int) -> int:
	return bx * BLOCK_W + 1 + int(rand01(bx * 7 + 5, k * 31 + 203, s) * float(BLOCK_W - 2))


static func is_solid(cx: int, cy: int, s: int) -> bool:
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

	# 层带中部的浮岛（只在平台上方的空隙里）
	if r >= 4 and r < 5 and top <= 1:
		if rand01(bx * 7 + 3, k * 31 + 202, s) < ISLAND_CHANCE:
			var ix := _island_x(bx, k, s)
			if cx == ix or cx == ix + 1:
				return true

	return false


## 玩家所在「层号」：地表为 0，越往下越大（y 轴向下为正）。
static func layer_of(py: float, tile: int) -> int:
	return fdiv(floori(py / float(tile)) + 1, BAND_ROWS)
