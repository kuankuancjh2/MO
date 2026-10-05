extends Node
## 截 UI：局内商店 + 全局商店 + 主画面

func _ready() -> void:
	await get_tree().process_frame
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	for i in range(40):
		await get_tree().physics_frame
	await _shot("ui_0_game")
	RunState.add_coins(30)
	main.open_shop()
	await get_tree().process_frame
	await _wait(8)
	await _shot("ui_1_shop")
	main.shop_ui.close()
	MetaState.souls = 120
	main.meta_shop.open(false)
	await get_tree().process_frame
	await _wait(8)
	await _shot("ui_2_meta")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://%s.png" % name
	img.save_png(path)
	print("  ", ProjectSettings.globalize_path(path))
