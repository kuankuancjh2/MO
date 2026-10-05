class_name Hud
extends CanvasLayer
## HUD：心、金币、偏旁 UI（字砖）、层数提示、横幅、交互提示、死亡遮罩、视野变暗。
## 视野变暗（「暮」的副作用）也在这里实现。

const TOAST_TIME := 2.2
const BANNER_TIME := 1.6

var _player: Player
var _dark: ColorRect
var _hp: Label
var _coin: Label
var _slots_ui: RadicalSlotsUI
var _toast: Label
var _banner_label: Label
var _prompt: Label
var _hint: Label
var _overlay: Label
var _overlay_sub: Label
var _toast_left := 0.0
var _banner_left := 0.0


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
	_toast = Assets.make_label("", int(fsize * 1.1), cfg.color_hud)
	_banner_label = Assets.make_label("", int(fsize * 1.25), cfg.color_coin)
	_prompt = Assets.make_label("", int(fsize * 1.05), cfg.color_coin)
	_hint = Assets.make_label("A/D 移动   空格 跳跃   鼠标左键 攻击   Q 技能   F 交互   R 重开",
		int(fsize * 0.7), cfg.color_hud_dim)
	_overlay = Assets.make_label("你散去了", cfg.hud_big_font_size, cfg.color_player)
	_overlay_sub = Assets.make_label("按 R 重新开始", fsize, cfg.color_hud_dim)
	for l in [_hp, _coin, _toast, _banner_label, _prompt, _hint, _overlay, _overlay_sub]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	for l in [_toast, _banner_label, _prompt, _hint, _overlay, _overlay_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.visible = false
	_overlay_sub.visible = false

	_slots_ui = RadicalSlotsUI.new()
	_slots_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots_ui)
	_slots_ui.setup(_player)

	_player.hp_changed.connect(_on_hp_changed)
	_player.layer_changed.connect(_on_layer_changed)
	RunState.coins_changed.connect(_on_coins_changed)
	_on_hp_changed(_player.hp, _player.max_hp)
	_on_coins_changed(RunState.coins)


func _process(delta: float) -> void:
	_layout(get_viewport().get_visible_rect().size)

	var target := 0.0
	if _player != null and is_instance_valid(_player):
		target = clampf((1.0 - _player.vision_factor) * 1.6, 0.0, 0.72)
	var c := _dark.color
	_dark.color = Color(0, 0, 0, lerpf(c.a, target, delta * 4.0))

	_toast_left = maxf(_toast_left - delta, 0.0)
	_toast.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)
	_banner_left = maxf(_banner_left - delta, 0.0)
	_banner_label.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)


func _layout(vp: Vector2) -> void:
	_dark.position = Vector2.ZERO
	_dark.size = vp
	_hp.position = Vector2(18, 12)
	_coin.position = Vector2(18, 44)
	_toast.size = Vector2(vp.x, 40)
	_toast.position = Vector2(0, 108)
	_banner_label.size = Vector2(vp.x, 44)
	_banner_label.position = Vector2(0, 158)
	_prompt.size = Vector2(vp.x, 34)
	_prompt.position = Vector2(0, vp.y - 92)
	_hint.size = Vector2(vp.x, 30)
	_hint.position = Vector2(0, vp.y - 32)
	_slots_ui.position = Vector2(18, vp.y - 132)
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


func _on_layer_changed(layer: int, went_down: bool) -> void:
	if went_down:
		toast("第 %d 层" % (layer + 1))


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = TOAST_TIME


## 中间偏上的横幅（踩怪、卸力、红字效果等即时反馈）
func banner(text: String, positive: bool = true) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color",
		Assets.cfg.color_coin if positive else Assets.cfg.color_enemy)
	_banner_label.modulate.a = 1.0
	_banner_left = BANNER_TIME


func show_radical(r: RadicalData) -> void:
	toast("莫 + %s = %s" % [r.radical_char, r.composed_char])


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_death() -> void:
	_overlay.visible = true
	_overlay_sub.visible = true


func hide_death() -> void:
	_overlay.visible = false
	_overlay_sub.visible = false
