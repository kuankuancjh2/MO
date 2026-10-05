class_name WordEnemyTable
extends RefCounted
## 普通敌人 = **彩色汉字**。
##
## 主题：`莫` = **无**。那敌人就是**"有"** —— 一切"不肯消失的东西"。
## 名字就是它们的性格，颜色就是它们的类别（不再清一色红）。
##
## behavior 决定用哪套 AI：
##   "walk" = 巡逻（遇墙/悬崖转身）  "chase" = 追人  "fly" = 飞行
##
## ★ 视觉约定：只画一个字，**没有底盘、没有圈、没有脸** —— 和"书写"的审美统一。
##   普通敌人 = 实心彩字；偏旁怪 = 空心描边字（另一类东西）。

const LIST := [
	{"glyph": "命", "name": "生命", "ink": "#b8342f", "behavior": "walk",
		"hp": 1.5, "coins": 2, "speed": 1.0},
	{"glyph": "乐", "name": "快乐", "ink": "#c99a1c", "behavior": "walk",
		"hp": 1.0, "coins": 2, "speed": 1.5},
	{"glyph": "利", "name": "利益", "ink": "#3f7a45", "behavior": "walk",
		"hp": 1.0, "coins": 5, "speed": 0.9},
	{"glyph": "权", "name": "权力", "ink": "#b06a1e", "behavior": "walk",
		"hp": 3.0, "coins": 3, "speed": 0.75},
	{"glyph": "色", "name": "形色", "ink": "#6b4b9e", "behavior": "chase",
		"hp": 1.5, "coins": 2, "speed": 1.0},
	{"glyph": "欲", "name": "欲望", "ink": "#b5476f", "behavior": "chase",
		"hp": 2.0, "coins": 3, "speed": 0.9},
	{"glyph": "名", "name": "名声", "ink": "#2f7d86", "behavior": "fly",
		"hp": 1.5, "coins": 2, "speed": 1.0},
	{"glyph": "妄", "name": "虚妄", "ink": "#5a5a5a", "behavior": "fly",
		"hp": 1.0, "coins": 2, "speed": 1.2},
]

## 按行为挑一个"字"（确定性随机 → 卸载重载不跳）
static func pick(behavior: String, r: float) -> Dictionary:
	var pool: Array = []
	for e in LIST:
		if e.get("behavior", "walk") == behavior:
			pool.append(e)
	if pool.is_empty():
		return LIST[0]
	return pool[int(clampf(r, 0.0, 0.9999) * float(pool.size())) % pool.size()]


static func size() -> int:
	return LIST.size()
