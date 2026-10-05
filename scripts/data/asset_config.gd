@tool
class_name AssetConfig
extends Resource
## ★ 美术资产的唯一入口。
## 换美术只需要改这个资源（assets/config/asset_config.tres），不需要动任何 .gd 脚本。
## 更多说明见 docs/技术文档.md 第 8 章。

@export_group("字体")
## 主字体。为空时使用下面配置的系统字体（系统字体自带中文，免打包）。
@export var main_font: Font
@export var use_system_font: bool = true
@export var system_font_names: PackedStringArray = PackedStringArray([
	"Microsoft YaHei", "SimHei", "Noto Sans SC", "PingFang SC", "Source Han Sans SC", "sans-serif"
])

@export_group("颜色")
## ★ 美术方向：**白纸上的墨线**（参考图就是这个语境）。
## 地图是黑白线稿，只有"活着的字"带颜色 —— 莫是黑墨（无），敌人是彩墨（有）。
@export var color_background := Color("#f4f2ee")      ## 纸
@export var color_player := Color("#14120f")          ## 莫：黑墨
@export var color_hp := Color("#a8342f")              ## 心：一点朱
@export var color_radical := Color("#24404f")         ## 偏旁的墨（略带靛）
@export var color_enemy := Color("#c03a3a")           ## 敌人的红
@export var color_coin := Color("#b8891c")            ## 金（压暗成墨金）
@export var color_solid_tile := Color("#ffffff")      ## 方块填充（程序占位用）
@export var color_solid_border := Color("#1a1a1a")
@export var color_tile_stepped := Color("#8a8a8a")
@export var color_tile_warn := Color("#a8342f")        ## 危险提示：朱
@export var color_grid := Color(0.0, 0.0, 0.0, 0.09)   ## 纸上的虚线格
@export var color_void_ghost := Color(0.0, 0.0, 0.0, 0.34)
@export var color_hud := Color("#1a1a1a")
@export var color_hud_dim := Color(0.34, 0.34, 0.34, 0.85)

@export_group("方块外观（留空则用程序绘制的方框）")
@export var solid_tile_texture: Texture2D
@export var void_tile_texture: Texture2D
@export var stepped_tile_texture: Texture2D

@export_group("字号")
@export var player_font_size: int = 40
@export var radical_font_size: int = 34
@export var enemy_font_size: int = 34
@export var hud_font_size: int = 22
@export var hud_big_font_size: int = 40
