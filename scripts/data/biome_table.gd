class_name BiomeTable
extends RefCounted
## 生物群系表：横向把地图切成几种「材质区」。
##
## ★ 风格约定：**地图保持黑白线稿**，所以这里不靠颜色区分，而是靠
## **纹理图案**（草皮/沙纹/砖砌/斜格）+ 极轻微的灰度差。
## 这正和参考图一致：白色填充 + 黑描边，只是图案不同。
##
## surface = 地表那一行用的砖（草/沙/顶线）
## fill    = 地体内部用的砖
## deco    = 长在地表上的装饰（无碰撞）

const LIST := [
	{
		"id": "grass", "name": "草原",
		"surface": "tile_grass", "fill": "tile_stone",
		"gray": 1.00,
		"deco": ["tile_bush", "tile_bushHalf", "tile_tree", "tile_treeTop",
			"tile_treeTrunk", "fence", "tile_fence", "pole", "star", "tile_crate"],
		"deco_chance": 0.18,
	},
	{
		"id": "sand", "name": "沙地",
		"surface": "tile_sand", "fill": "tile_sand",
		"gray": 0.93,
		"deco": ["cactus", "pottery", "pottery_tall", "tile_bushHalf",
			"tile_crate", "tile_crateSmall", "tile_crateDiagonal", "star"],
		"deco_chance": 0.15,
	},
	{
		"id": "stone", "name": "石城",
		"surface": "tile_top", "fill": "tile_brick",
		"gray": 0.86,
		# 注意：窗/柱头这类"贴在墙上"的构件不放地面装饰，
		# 孤零零立在土上看着很怪 —— 它们由结构（建筑）去用。
		"deco": ["column", "pole", "pole_lantern", "tile_crate", "carpet",
			"tile_cog", "tile_flag", "tile_bushHalf"],
		"deco_chance": 0.18,
	},
	{
		"id": "ruin", "name": "遗迹",
		"surface": "tile_diagonal", "fill": "tile_diagonal",
		"gray": 0.78,
		"deco": ["obelisk", "column", "archway_small", "archway_small_decorative",
			"pottery_tall", "star", "smoke", "tile_gem", "triangle", "tile_bushHalf"],
		"deco_chance": 0.17,
	},
]

static func count() -> int:
	return LIST.size()


static func get_biome(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


static func surface_tex(i: int) -> String:
	return String(get_biome(i).get("surface", "tile_top"))


static func fill_tex(i: int) -> String:
	return String(get_biome(i).get("fill", "tile_stone"))


## 灰度：让玩家一眼看出"换区了"，但仍然是黑白
static func gray(i: int) -> float:
	return float(get_biome(i).get("gray", 1.0))


static func deco(i: int) -> Array:
	return get_biome(i).get("deco", [])


static func deco_chance(i: int) -> float:
	return float(get_biome(i).get("deco_chance", 0.12))


## 主色（HUD 提示"进入某区"时用；地图本身不带色）
static func name_of(i: int) -> String:
	return String(get_biome(i).get("name", "?"))
