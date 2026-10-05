extends Node
## 素材边缘探针：量出每张图的「非透明内容包围盒」，
## 用来判断方块之间为什么会有空隙，以及装饰为什么"浮"在地上。
##   Tools/Godot_console.exe --path . res://devtools/art_probe.tscn

func _ready() -> void:
	await get_tree().process_frame
	var dir := DirAccess.open("res://assets/art/textures")
	if dir == null:
		print("找不到目录")
		get_tree().quit()
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.get_extension().to_lower() == "png":
			names.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	names.sort()

	print("名称 | 尺寸 | 内容bbox | 左/上/右/下留白")
	var insets := {}
	for n in names:
		var tex := Assets.get_art(n)
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		var bb := _bbox(img)
		if bb.size.x <= 0:
			print("  %-28s 全透明" % n)
			continue
		var w := img.get_width()
		var h := img.get_height()
		var l := bb.position.x
		var t := bb.position.y
		var r := w - (bb.position.x + bb.size.x)
		var b := h - (bb.position.y + bb.size.y)
		var key := "%d,%d,%d,%d" % [l, t, r, b]
		insets[key] = int(insets.get(key, 0)) + 1
		if n.begins_with("tile_") or n.begins_with("bridge_") or n.begins_with("column") \
				or n.begins_with("roof") or n.begins_with("castle") or n.begins_with("tower"):
			print("  %-28s %dx%d  %dx%d@%d,%d  留白 %d/%d/%d/%d"
				% [n, w, h, bb.size.x, bb.size.y, bb.position.x, bb.position.y, l, t, r, b])
	print("--- 留白分布（留白组合 -> 张数）---")
	for k in insets.keys():
		print("  %s : %d 张" % [k, insets[k]])
	get_tree().quit()


func _bbox(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.02:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
