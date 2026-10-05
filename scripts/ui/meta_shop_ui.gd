class_name MetaShopUI
extends CanvasLayer
## ★ 全局商店：花**魂币**买永久成长（跨局保留，存在 user://mo_save.json）。
##
## 打开方式：死亡后自动弹出；或随时按 TAB。
## 面板用素材里的 ui_box 当底，和地图一样是纸墨风。

signal closed

const PANEL := Vector2(560, 372)

## id / 名称 / 说明 / 基础价 / 每级涨幅 / 上限
const ITEMS := [
	{"id": "hp", "name": "心", "desc": "最大心 +1", "cost": 18, "step": 14, "max": 4},
	{"id": "speed", "name": "行", "desc": "移速 +5%", "cost": 14, "step": 10, "max": 5},
	{"id": "vanish", "name": "固", "desc": "地面消失更慢 +8%", "cost": 16, "step": 12, "max": 5},
	{"id": "atk", "name": "锋", "desc": "攻击 +15%", "cost": 16, "step": 12, "max": 4},
	{"id": "dash", "name": "驰", "desc": "冲刺冷却 -15%", "cost": 20, "step": 14, "max": 3},
]

var _open := false
var _from_death := false
var _panel: NinePatchRect
var _title: Label
var _souls: Label
var _msg: Label
var _rows: Array[Label] = []


func setup() -> void:
	var cfg := Assets.cfg
	_panel = NinePatchRect.new()
	_panel.texture = Assets.get_art("ui_box")
	_panel.patch_margin_left = 26
	_panel.patch_margin_right = 26
	_panel.patch_margin_top = 26
	_panel.patch_margin_bottom = 26
	_panel.modulate = Color(1, 1, 1, 0.97)
	add_child(_panel)

	_title = Assets.make_label("全局商店 · 魂币换永久成长", cfg.hud_big_font_size, cfg.color_hud)
	_souls = Assets.make_label("", cfg.hud_font_size, cfg.color_hp)
	_msg = Assets.make_label("按 1~5 购买    TAB / ESC 关闭", int(cfg.hud_font_size * 0.85),
		cfg.color_hud_dim)
	add_child(_title)
	add_child(_souls)
	add_child(_msg)
	for i in range(ITEMS.size()):
		var l := Assets.make_label("", int(cfg.hud_font_size * 0.95), cfg.color_hud)
		add_child(l)
		_rows.append(l)
	visible = false
	MetaState.souls_changed.connect(_on_souls)


func is_open() -> bool:
	return _open


func open(from_death: bool = false) -> void:
	_open = true
	_from_death = from_death
	visible = true
	_msg.text = ("你散去了 —— 用魂币买点东西，再按 R 重来" if from_death
		else "按 1~5 购买    TAB / ESC 关闭")
	_refresh()


func close() -> void:
	_open = false
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if not _open:
		return
	_layout(get_viewport().get_visible_rect().size)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = (event as InputEventKey).physical_keycode
	if code == KEY_ESCAPE or code == KEY_TAB:
		close()
		get_viewport().set_input_as_handled()
		return
	for i in range(ITEMS.size()):
		if code == KEY_1 + i:
			_buy(i)
			get_viewport().set_input_as_handled()
			return


func _layout(vp: Vector2) -> void:
	var pos := Vector2(vp.x * 0.5 - PANEL.x * 0.5, vp.y * 0.5 - PANEL.y * 0.5)
	_panel.position = pos
	_panel.size = PANEL
	_title.position = pos + Vector2(26, 16)
	_souls.position = pos + Vector2(28, 58)
	_msg.position = pos + Vector2(28, PANEL.y - 42)
	for i in range(_rows.size()):
		_rows[i].position = pos + Vector2(30, 104 + i * 40.0)


func _cost(i: int) -> int:
	var it: Dictionary = ITEMS[i]
	var lv := MetaState.get_upgrade(String(it["id"]))
	return int(it["cost"]) + int(it["step"]) * lv


func _refresh() -> void:
	_souls.text = "魂币 %d" % MetaState.souls
	for i in range(_rows.size()):
		var it: Dictionary = ITEMS[i]
		var lv := MetaState.get_upgrade(String(it["id"]))
		var mx := int(it["max"])
		var full := lv >= mx
		var c := _cost(i)
		var col: Color = Assets.cfg.color_hud
		if full:
			col = Assets.cfg.color_hud_dim
		elif MetaState.souls < c:
			col = Assets.cfg.color_enemy
		_rows[i].add_theme_color_override("font_color", col)
		var tail := "（已满级）" if full else ("  %d 魂币" % c)
		_rows[i].text = "%d. %s   %s%s   [%d/%d]" % [i + 1, it["name"], it["desc"], tail, lv, mx]


func _on_souls(_n: int) -> void:
	if _open:
		_refresh()


func _buy(i: int) -> void:
	var it: Dictionary = ITEMS[i]
	var lv := MetaState.get_upgrade(String(it["id"]))
	if lv >= int(it["max"]):
		_msg.text = "已经满级了"
		return
	var c := _cost(i)
	if MetaState.souls < c:
		_msg.text = "魂币不够（需要 %d，你有 %d）" % [c, MetaState.souls]
		_refresh()
		return
	if MetaState.buy(String(it["id"]), c, int(it["max"])):
		Sfx.play("coin")
		_msg.text = "买到：%s（下一局生效）" % it["name"]
	_refresh()
