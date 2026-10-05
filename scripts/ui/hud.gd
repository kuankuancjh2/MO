class_name Hud
extends CanvasLayer
## HUD：心（血量）、金币、携带的字（偏旁槽位）、层数提示、死亡遮罩。
## 视野变暗（「暮」的副作用）也在这里实现。

const TOAST_TIME := 2.2

var _player: Player
var _dark: ColorRect
var _hp: Label
var _coin: Label
var _slots: Label
var _slot_desc: Label
var _toast: Label
var _hint: Label
var _overlay: Label
var _overlay_sub: Label
var _toast_left := 0.0


func setup(p: Player) -> void:
	_player = p
	_dark = ColorRect.new()
	_dark.color = Color(0, 0, 0, 0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)

	var cfg := Assets.cfg
	var fsize := cfg.hud_font_size
	_hp = Assets.make_label("", fsize, cfg.color_hp)
	_coin = Assets.make_label("", fsize, cfg.color_coin)
	_slots = Assets.make_label("", fsize, cfg.color_radical)
	_slot_desc = Assets.make_label("", int(fsize * 0.72), cfg.color_hud_dim)
	_toast = Assets.make_label("", int(fsize * 1.15), cfg.color_hud)
	_hint = Assets.make_label("A/D 移动   空格 跳跃   J 攻击   Q 技能   R 重开", int(fsize * 0.7), cfg.color_hud_dim)
	_overlay = Assets.make_label("你散去了", cfg.hud_big_font_size, cfg.color_player)
	_overlay_sub = Assets.make_label("按 R 重新开始", fsize, cfg.color_hud_dim)
	for l in [_hp, _coin, _slots, _slot_desc, _toast, _hint, _overlay, _overlay_sub]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.visible = false
	_overlay_sub.visible = false

	_player.hp_changed.connect(_on_hp_changed)
	_player.layer_changed.connect(_on_layer_changed)
	RunState.coins_changed.connect(_on_coins_changed)
	RunState.radicals_changed.connect(_refresh_slots)
	_on_hp_changed(_player.hp, _player.max_hp)
	_on_coins_changed(RunState.coins)
	_refresh_slots()


func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	_layout(vp)
	# 视野变暗（暮）
	var target := 0.0
	if _player != null and is_instance_valid(_player):
		target = clampf((1.0 - _player.vision_factor) * 1.6, 0.0, 0.72)
	var c := _dark.color
	_dark.color = Color(0, 0, 0, lerpf(c.a, target, delta * 4.0))

	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)
	else:
		_toast.modulate.a = 0.0


func _layout(vp: Vector2) -> void:
	_dark.position = Vector2.ZERO
	_dark.size = vp
	_hp.position = Vector2(18, 12)
	_coin.position = Vector2(18, 44)
	_slots.position = Vector2(18, 76)
	_slot_desc.position = Vector2(18, 104)
	_toast.size = Vector2(vp.x, 40)
	_toast.position = Vector2(0, 118)
	_hint.size = Vector2(vp.x, 30)
	_hint.position = Vector2(0, vp.y - 34)
	_overlay.size = Vector2(vp.x, 60)
	_overlay.position = Vector2(0, vp.y * 0.5 - 50)
	_overlay_sub.size = Vector2(vp.x, 40)
	_overlay_sub.position = Vector2(0, vp.y * 0.5 + 18)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	var s := ""
	var full := int(ceilf(hp))
	for i in range(int(max_hp)):
		s += "心" if i < full else "－"
	_hp.text = s


func _on_coins_changed(coins: int) -> void:
	_coin.text = "金 %d" % coins


func _refresh_slots() -> void:
	if RunState.radicals.is_empty():
		_slots.text = "字：莫"
		_slot_desc.text = "（去捡偏旁，把「莫」填成新的字）"
		return
	var names: Array[String] = ["莫"]
	for r in RunState.radicals:
		names.append(r.composed_char)
	_slots.text = "字：" + "".join(names)
	var lines: Array[String] = []
	for r in RunState.radicals:
		lines.append("%s：%s" % [r.composed_char, r.summary()])
	_slot_desc.text = "\n".join(lines)


func _on_layer_changed(layer: int, went_down: bool) -> void:
	if went_down:
		toast("第 %d 层" % (layer + 1))


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = TOAST_TIME


func show_radical(r: RadicalData) -> void:
	toast("莫 + %s = %s" % [r.radical_char, r.composed_char])


func show_death() -> void:
	_overlay.visible = true
	_overlay_sub.visible = true


func hide_death() -> void:
	_overlay.visible = false
	_overlay_sub.visible = false
