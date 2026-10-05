extends Node2D
## 主场景：组装整个游戏（世界 / 主角 / 相机 / HUD）。
## 节点结构在代码里搭，.tscn 只留一个根节点 —— 这样场景文件不会写错，
## 同时美术资源全部走 AssetConfig。

var world: GameWorld
var player: Player
var hud: Hud
var grid: GridBackground


func _ready() -> void:
	add_to_group("main")
	RunState.reset()

	grid = GridBackground.new()
	add_child(grid)

	world = GameWorld.new()
	add_child(world)

	# 注意：物理体必须在「进入场景树之前」就摆好位置。
	# 否则它会以 (0,0) 注册进物理世界，而 (0,0) 往往正好在方块内部，
	# 物理引擎会把它"解穿透"弹飞出去。
	# 主角挂在 world 底下：这样他的投射物、敌人、金币都住在同一个容器里。
	player = Player.new()
	player.add_to_group("player")
	player.position = world.spawn_point()
	world.add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	player.add_child(cam)
	cam.make_current()

	world.setup(player)

	hud = Hud.new()
	add_child(hud)
	hud.setup(player)

	player.died.connect(_on_player_died)


func _on_player_died() -> void:
	if hud != null:
		hud.show_death()
	# 死亡结算：把这一局的进度换成魂币，留给下一局买全局成长
	MetaState.add_souls(3 + maxi(0, RunState.coins / 2))


func announce_radical(r: RadicalData) -> void:
	if hud != null:
		hud.show_radical(r)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
