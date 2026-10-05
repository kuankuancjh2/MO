class_name StructureData
extends Resource
## 一个可以嵌进地形的「结构」，格式是一张字符网格（思路同 MC 的 schematic）。
##
## 网格的**最后一行对齐"玩家身体行"**（平台顶上面那一格），往上依次是 -2、-3…
## 例如 height = 5 的结构，第 0 行在世界里就是 base_row - 5。
##
## ⚠️ 硬性要求：**最后一行（地面层）必须左右贯通**。
## 玩家永远向右走，任何左右封死的地面层都等于卡死。
##
## 字符表：
##   '#' 实心方块      'W' 字块（实心，撞碎得字）
##   'E' 巡逻怪        'K' 猎手        'F' 飞怪      'R' 红偏旁怪
##   'S' 商店          '.' 空

const SOLID_CHARS := "#W"

@export var id: String = ""
@export var display_name: String = ""
@export var grid: PackedStringArray = PackedStringArray()
@export var weight: float = 1.0
@export var tags: PackedStringArray = PackedStringArray()


func width() -> int:
	if grid.is_empty():
		return 0
	var w := 0
	for row in grid:
		w = maxi(w, row.length())
	return w


func height() -> int:
	return grid.size()


func cell(col: int, row: int) -> String:
	if row < 0 or row >= grid.size():
		return "."
	var line := grid[row]
	if col < 0 or col >= line.length():
		return "."
	return line[col]


## 地面层（最后一行）是否左右贯通 —— 生成器会用它做自检
func ground_row_is_open() -> bool:
	if grid.is_empty():
		return true
	var last := grid[grid.size() - 1]
	for i in range(last.length()):
		if SOLID_CHARS.contains(last[i]):
			return false
	return true
