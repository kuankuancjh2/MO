extends Node2D
## 主场景：组装整个游戏（世界 / 主角 / 相机 / HUD / 商店界面）。
## 节点结构在代码里搭，.tscn 只留一个根节点 —— 场景文件不会写错，
## 同时美术资源全部走 AssetConfig。

var world: GameWorld
var player: Player
var hud: Hud
var grid: GridBackground
var shop_ui: ShopUI
var meta_shop: MetaShopUI


func _ready() -> void:
	add_to_group("main")
	# 白纸：背景色由资产配置决定（美术方向是"纸上的墨线"）
	RenderingServer.set_default_clear_color(Assets.cfg.color_background)
	RunState.reset()

	grid = GridBackground.new()
	add_child(grid)

	world = GameWorld.new()
	add_child(world)

	# 注意：物理体必须在「进入场景树之前」就摆好位置。
	# 否则它会以 (0,0) 注册进物理世界，而 (0,0) 往往正好在方块内部，
	# 物理引擎会把它"解穿透"弹飞出去。
	# 主角挂在 world 底下：他的投射物、敌人、金币都住在同一个容器里。
	player = Player.new()
	player.add_to_group("player")
	player.position = world.spawn_point()
	world.add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	# ★ 过采样：世界被放大到素材原生尺寸（格子 128），相机缩放拉回来，
	#   于是可见范围、手感、跳跃格数都和以前完全一样，但素材是 1:1 进渲染的。
	cam.zoom = Vector2.ONE * Balance.camera_zoom()
	player.add_child(cam)
	cam.make_current()

	world.setup(player)

	hud = Hud.new()
	add_child(hud)
	hud.setup(player)

	shop_ui = ShopUI.new()
	add_child(shop_ui)
	shop_ui.setup(player)

	meta_shop = MetaShopUI.new()
	add_child(meta_shop)
	meta_shop.setup()

	player.died.connect(_on_player_died)


func _on_player_died() -> void:
	if hud != null:
		hud.show_death()
		hud.set_prompt("")
	# 死亡结算：把这一局的进度换成魂币，留给下一局买全局成长
	MetaState.add_souls(3 + maxi(0, RunState.coins / 2))
	# ★ 死掉直接弹全局商店：拿魂币换永久成长，再按 R 重来
	if meta_shop != null:
		meta_shop.open(true)


func announce_radical(r: RadicalData) -> void:
	if hud != null:
		hud.show_radical(r)


## 即时反馈横幅（踩怪 / 卸力 / 红字效果…）
func announce_text(text: String, positive: bool = true) -> void:
	if hud != null:
		hud.banner(text, positive)


func set_prompt(text: String) -> void:
	if hud != null:
		hud.set_prompt(text)


func open_shop() -> void:
	if shop_ui != null and not shop_ui.is_open():
		shop_ui.open_shop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	# TAB 随时开全局商店
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_TAB:
		if meta_shop != null:
			if meta_shop.is_open():
				meta_shop.close()
			else:
				meta_shop.open(false)
		get_viewport().set_input_as_handled()
