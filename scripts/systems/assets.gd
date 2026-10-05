extends Node
## 资产单例：加载 asset_config 并对外提供统一的字体 / 颜色。
## 全项目获取美术资源都走这里，确保「换美术只改一个配置文件」。

const CONFIG_PATH := "res://assets/config/asset_config.tres"

var cfg: AssetConfig
var font: Font


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		cfg = load(CONFIG_PATH) as AssetConfig
	if cfg == null:
		cfg = AssetConfig.new()
	_setup_font()


func _setup_font() -> void:
	if cfg.main_font != null:
		font = cfg.main_font
		return
	if cfg.use_system_font:
		var sf := SystemFont.new()
		sf.font_names = cfg.system_font_names
		sf.allow_system_fallback = true
		font = sf
	else:
		font = ThemeDB.fallback_font


## 便捷：造一个已经套好字体/字号/颜色的 Label。
func make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
