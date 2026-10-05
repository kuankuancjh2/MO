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
@export var color_background := Color("#0d0d10")
@export var color_player := Color("#f5f5f2")
@export var color_hp := Color("#ff6b6b")
@export var color_radical := Color("#8fd0ff")
@export var color_enemy := Color("#e23b3b")
@export var color_coin := Color("#ffd23b")
@export var color_solid_tile := Color("#343a46")
@export var color_solid_border := Color("#6b7280")
@export var color_tile_stepped := Color("#8a6a3a")
@export var color_tile_warn := Color("#e23b3b")
@export var color_grid := Color(1.0, 1.0, 1.0, 0.055)
@export var color_void_ghost := Color(1.0, 1.0, 1.0, 0.30)
@export var color_hud := Color("#e8e8e4")
@export var color_hud_dim := Color(0.72, 0.72, 0.70, 0.55)

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
