class_name ShopUI
extends CanvasLayer
## 局内商店：花**金币**买当局补给。
##
## ★ 故意**不做全屏遮罩**：面板挂在右上角，主角和脚下一直看得见 ——
##   因为买东西的时候时间没有停，你脚下的方块还在倒计时。
##   面板底用素材 ui_box（九宫格拉伸），和地图一样是纸墨风。

signal closed

const OPEN_GUARD := 0.15
const PANEL := Vector2(500, 250)

var _player: Player
var _open := false
var _guard := 0.0
var _bg: ColorRect
var _panel: NinePatchRect
var _title: Label
var _msg: Label
var _note: Label
var _rows: Array[Label] = []
var _items: Array = []


func setup(p: Player) -> void:
	_player = p
	var cfg := Assets.cfg
	# 兜底底色（没有 ui_box 素材时也能看清）
	_bg = ColorRect.new()
	_bg.color = Color(1, 1, 1, 0.94)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	var box := Assets.get_art("ui_box")
	if box != null:
		_panel = NinePatchRect.new()
		_panel.texture = box
		_panel.patch_margin_left = 26
		_panel.patch_margin_right = 26
		_panel.patch_margin_top = 26
		_panel.patch_margin_bottom = 26
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_panel)
	_title = Assets.make_label("商店", cfg.hud_big_font_size, cfg.color_hud)
	_msg = Assets.make_label("", int(cfg.hud_font_size * 0.85), cfg.color_hud)
	_note = Assets.make_label("时间不会停 —— 你脚下的方块还在塌",
		int(cfg.hud_font_size * 0.8), cfg.color_tile_warn)
	add_child(_title)
	add_child(_msg)
	add_child(_note)
	_rebuild_items()
	for i in range(_items.size()):
		var l := Assets.make_label("", int(cfg.hud_font_size * 0.92), cfg.color_hud)
		add_child(l)
		_rows.append(l)
	visible = false


func _rebuild_items() -> void:
	var b := Balance.d
	_items = [
		{
			"name": "回心", "price": b.shop_heal_price, "note": "回复 1 心",
			"apply": func() -> void: _player.heal(1.0),
			"sold": func() -> bool: return false,
		},
		{
			"name": "换一个字", "price": b.shop_word_price, "note": "立刻抽一个随机的字",
			"apply": func() -> void: _grant_random_word(),
			"sold": func() -> bool: return false,
		},
		{
			"name": "续字", "price": b.shop_extend_price, "note": "当前的字 +12 秒",
			"apply": func() -> void: RunState.extend_radical(12.0),
			"sold": func() -> bool: return RunState.radicals.is_empty(),
		},
	]


func _grant_random_word() -> void:
	if not ResourceLoader.exists("res://data/radical_library.tres"):
		return
	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	if lib == null or lib.radicals.is_empty():
		return
	var d: RadicalData = lib.radicals[randi() % lib.radicals.size()]
	RunState.add_radical(d)
	RadicalEffects.on_pickup(_player, d)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("announce_radical"):
		main.announce_radical(d)


func open_shop() -> void:
	_open = true
	_guard = OPEN_GUARD
	visible = true
	_player.input_locked = true
	_msg.text = "按 1 / 2 / 3 购买    F 或 ESC 关闭"
	_refresh_rows()


func close() -> void:
	_open = false
	visible = false
	_player.input_locked = false
	closed.emit()


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	if not _open:
		return
	_guard = maxf(_guard - delta, 0.0)
	_refresh_rows()
	_layout(get_viewport().get_visible_rect().size)


func _input(event: InputEvent) -> void:
	if not _open or _guard > 0.0:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = (event as InputEventKey).physical_keycode
	if code == KEY_ESCAPE or code == KEY_F:
		close()
		get_viewport().set_input_as_handled()
		return
	for i in range(_items.size()):
		if code == KEY_1 + i:
			_try_buy(i)
			get_viewport().set_input_as_handled()
			return


## 右上角，避开屏幕中央的主角与脚下的地面
func _layout(vp: Vector2) -> void:
	var pos := Vector2(vp.x - PANEL.x - 20.0, 46.0)
	_bg.position = pos
	_bg.size = PANEL
	if _panel != null:
		_panel.position = pos
		_panel.size = PANEL
	_title.position = pos + Vector2(24, 12)
	_msg.position = pos + Vector2(24, 56)
	_note.position = pos + Vector2(24, PANEL.y - 34.0)
	for i in range(_rows.size()):
		_rows[i].position = pos + Vector2(26, 92 + i * 32.0)


func _refresh_rows() -> void:
	for i in range(_rows.size()):
		if i >= _items.size():
			_rows[i].text = ""
			continue
		var it: Dictionary = _items[i]
		var sold: bool = (it["sold"] as Callable).call()
		var ok: bool = RunState.coins >= int(it["price"])
		var color := Assets.cfg.color_hud
		if sold:
			color = Assets.cfg.color_hud_dim
		elif not ok:
			color = Assets.cfg.color_enemy
		_rows[i].add_theme_color_override("font_color", color)
		var state := ""
		if sold:
			state = "（现在不需要）"
		elif not ok:
			state = "（还差 %d 金）" % (int(it["price"]) - RunState.coins)
		_rows[i].text = "%d. %s   %d 金   %s %s" % [
			i + 1, it["name"], int(it["price"]), it["note"], state]


func _try_buy(i: int) -> void:
	var it: Dictionary = _items[i]
	if (it["sold"] as Callable).call():
		_msg.text = "现在不需要这个"
		return
	var price := int(it["price"])
	if RunState.coins < price:
		_msg.text = "金币不够（需要 %d，你有 %d）" % [price, RunState.coins]
		_refresh_rows()
		return
	RunState.add_coins(-price)
	(it["apply"] as Callable).call()
	Sfx.play("coin")
	_msg.text = "买下了：%s" % it["name"]
	_refresh_rows()
