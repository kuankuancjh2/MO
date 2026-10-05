extends Node
## 资产单例：加载 asset_config 并对外提供统一的字体 / 颜色。
## 全项目获取美术资源都走这里，确保「换美术只改一个配置文件」。

const CONFIG_PATH := "res://assets/config/asset_config.tres"
const ART_DIR := "res://assets/art"
const ART_EXTS := ["png", "jpg", "jpeg", "webp"]

var cfg: AssetConfig
var font: Font
var _art_cache: Dictionary = {}
var _art_found: Array[String] = []


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		cfg = load(CONFIG_PATH) as AssetConfig
	if cfg == null:
		cfg = AssetConfig.new()
	_setup_font()
	_scan_art()


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


## ── 美术资源替换（和音频一样：放文件即生效，不改代码）──────────
## 把图丢进 res://assets/art/，文件名见 docs/美术资源指南.md。
## 找不到就用程序画的占位图。

func get_art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var tex: Texture2D = null
	for ext in ART_EXTS:
		var path := "%s/%s.%s" % [ART_DIR, name, ext]
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_art_cache[name] = tex
	return tex


## 序列帧：player_run_01.png / _02 / _03… 有多少张就返回多少张
func get_frames(base: String) -> Array:
	var out: Array = []
	for i in range(1, 65):
		var t := get_art("%s_%02d" % [base, i])
		if t == null:
			break
		out.append(t)
	return out


func has_art(name: String) -> bool:
	return get_art(name) != null


func _scan_art() -> void:
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		print("MO: 没有 res://assets/art/ 目录，全部使用程序绘制的占位图。")
		print("    要换美术：把图片丢进 assets/art/，文件名见 docs/美术资源指南.md")
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f != "README.md":
			_art_found.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	if _art_found.is_empty():
		print("MO: assets/art/ 是空的，使用程序绘制的占位图。")
	else:
		print("MO: 已加载 %d 个美术资源（assets/art/）。" % _art_found.size())



## 便捷：造一个已经套好字体/字号/颜色的 Label。
func make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
