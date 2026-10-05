extends Node
## 资产单例：加载 asset_config 并对外提供统一的字体 / 颜色。
## 全项目获取美术资源都走这里，确保「换美术只改一个配置文件」。

const CONFIG_PATH := "res://assets/config/asset_config.tres"
const ART_DIR := "res://assets/art"
const ART_EXTS := ["png", "jpg", "jpeg", "webp"]

var cfg: AssetConfig
var font: Font
var _art_cache: Dictionary = {}
var _art_index: Dictionary = {}
var _art_found: Array[String] = []


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		cfg = load(CONFIG_PATH) as AssetConfig
	if cfg == null:
		cfg = AssetConfig.new()
	_scale_fonts()
	_setup_font()
	_scan_art()


## 过采样：世界空间里的字号要跟着格子一起放大（HUD 是屏幕空间，不缩放）
func _scale_fonts() -> void:
	var k := Balance.px
	if is_equal_approx(k, 1.0):
		return
	cfg.player_font_size = int(round(float(cfg.player_font_size) * k))
	cfg.radical_font_size = int(round(float(cfg.radical_font_size) * k))
	cfg.enemy_font_size = int(round(float(cfg.enemy_font_size) * k))


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
## 把图丢进 res://assets/art/ **或它的任意子目录**，文件名见 docs/美术资源指南.md。
## 找不到就用程序画的占位图。
## 说明：Godot 的 ResourceLoader 按路径缓存 —— 同一个文件加载 N 次返回同一个
## Texture2D 实例，内存里只有一份。所以这里不存在"存了一堆一样的素材"的问题。

func get_art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var tex: Texture2D = null
	# 1) 先在启动时建立的文件名索引里找（支持子目录）
	var path: String = _art_index.get(name, "")
	if path != "":
		tex = load(path) as Texture2D
	# 2) 兜底：直接按 res://assets/art/<name>.<ext> 探（导出后索引可能扫不到）
	if tex == null:
		for ext in ART_EXTS:
			var p := "%s/%s.%s" % [ART_DIR, name, ext]
			if ResourceLoader.exists(p):
				tex = load(p) as Texture2D
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


## 启动时递归扫一遍 assets/art/（含子目录），建「文件名(无扩展) -> 完整路径」索引
func _scan_art() -> void:
	_index_art(ART_DIR)
	if _art_index.is_empty():
		print("MO: assets/art/ 里没找到图片，全部使用程序绘制的占位图。")
	else:
		print("MO: 已索引 %d 张美术素材（assets/art/，含子目录）。" % _art_index.size())


func _index_art(dir_path: String, depth: int = 0) -> void:
	if depth > 3:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if not f.begins_with("."):
				_index_art("%s/%s" % [dir_path, f], depth + 1)
		else:
			var ext := f.get_extension().to_lower()
			if ART_EXTS.has(ext) and not f.ends_with(".import") and not f.ends_with(".remap"):
				_art_index[f.get_basename()] = "%s/%s" % [dir_path, f]
				_art_found.append(f)
		f = dir.get_next()
	dir.list_dir_end()



## 便捷：造一个已经套好字体/字号/颜色的 Label。
func make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
