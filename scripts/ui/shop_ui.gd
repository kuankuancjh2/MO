class_name ShopUI
extends CanvasLayer
## 商店界面。按 1/2/3 购买，按 F 或 ESC 关闭。
## 打开时锁住主角输入（不暂停场景树，省得和物理/测试互相打架）。

signal closed

const OPEN_GUARD := 0.15   ## 刚打开的这一瞬间忽略输入，避免开店的 F 顺手把店关了

var _player: Player
var _open := false
var _guard := 0.0
var _bg: ColorRect
var _title: Label
var _msg: Label
var _rows: Array[Label] = []
var _items: Array = []


func setup(p: Player) -> void:
	_player = p
	var cfg := Assets.cfg
	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.04, 0.06, 0.93)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_title = Assets.make_label("商店", cfg.hud_big_font_size, cfg.color_coin)
	_msg = Assets.make_label("", cfg.hud_font_size, cfg.color_hud_dim)
	add_child(_title)
	add_child(_msg)
	for i in range(3):
		var l := Assets.make_label("", cfg.hud_font_size, cfg.color_hud)
		add_child(l)
		_rows.append(l)
	_rebuild_items()
	visible = false


func _rebuild_items() -> void:
	var b := Balance.d
	_items = [
		{
			"name": "回心", "price": b.shop_heal_price, "note": "回复 1 心",
			"apply": func() -> void: _player.heal(1.0),
			"sold_out": func() -> bool: return false,
		},
		{
			"name": "随机一个字", "price": b.shop_word_price, "note": "立刻获得一个随机字的效果",
			"apply": func() -> void: _grant_random_word(),
			"sold_out": func() -> bool: return false,
		},
		{
			"name": "加一个槽位", "price": b.shop_slot_price, "note": "本局可多带一个字（限一次）",
			"apply": func() -> void: RunState.slot_count += 1,
			"sold_out": func() -> bool: return RunState.slot_count > _base_slots(),
		},
	]


func _base_slots() -> int:
	return Balance.d.radical_slots_base + int(MetaState.get_upgrade("slots")) + 1


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
	var vp := get_viewport().get_visible_rect().size
	_layout(vp)


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


func _layout(vp: Vector2) -> void:
	_bg.position = Vector2.ZERO
	_bg.size = vp
	_title.position = Vector2(vp.x * 0.5 - 44.0, vp.y * 0.5 - 150.0)
	_msg.position = Vector2(vp.x * 0.5 - 250.0, vp.y * 0.5 + 100.0)
	for i in range(_rows.size()):
		_rows[i].position = Vector2(vp.x * 0.5 - 250.0, vp.y * 0.5 - 90.0 + i * 38.0)


func _refresh_rows() -> void:
	for i in range(_rows.size()):
		if i >= _items.size():
			_rows[i].text = ""
			continue
		var it: Dictionary = _items[i]
		var sold: bool = (it["sold_out"] as Callable).call()
		var affordable: bool = RunState.coins >= int(it["price"])
		var color := Assets.cfg.color_hud
		if sold:
			color = Assets.cfg.color_hud_dim
		elif not affordable:
			color = Assets.cfg.color_enemy
		_rows[i].add_theme_color_override("font_color", color)
		var state := ""
		if sold:
			state = "（已售出）"
		elif not affordable:
			state = "（还差 %d 金币）" % (int(it["price"]) - RunState.coins)
		_rows[i].text = "%d. %s    %d 金币    %s  %s" % [
			i + 1, it["name"], int(it["price"]), it["note"], state]


func _try_buy(i: int) -> void:
	var it: Dictionary = _items[i]
	if (it["sold_out"] as Callable).call():
		_msg.text = "这个已经买过了"
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


func _on_coins_changed(_coins: int) -> void:
	if _open:
		_refresh_rows()
