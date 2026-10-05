extends Node
## 截图工具：从出生点跑一小段，存几张图，方便肉眼检查画面。
##   Tools/Godot_console.exe --path . res://devtools/shot.tscn
## 输出在 user://shot_*.png

func _ready() -> void:
	await get_tree().process_frame
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var p: Player = main.player

	await _shot("shot_0_spawn")

	# 往右走一段，看看地形与结构
	Input.action_press("move_right")
	await _wait(150)
	await _shot("shot_1_walk")
	await _wait(150)
	await _shot("shot_2_walk2")

	# 给几个字，看看偏旁 UI 和变字
	var lib := load("res://data/radical_library.tres") as RadicalLibrary
	if lib != null:
		RunState.add_radical(lib.find_by_id("mo_ri"))
		RunState.add_radical(lib.find_by_id("mo_xin"))
	Input.action_release("move_right")
	await _wait(30)
	await _shot("shot_3_words")

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
