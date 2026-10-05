extends SceneTree
## 用 Godot 自己生成 .tres 资源文件，避免手写资源格式出错。
##
## 用法：
##   Tools/Godot_console.exe --headless --path . --script res://tools/gen_resources.gd
##
## 生成的资源是「默认值快照」。之后在编辑器里改这些 .tres 就是改数值，不用碰代码。

func _initialize() -> void:
	_ensure_dirs()
	_gen_asset_config()
	_gen_balance()
	_gen_radical_library()
	_gen_structure_library()
	print("MO: 资源生成完毕。")
	quit()


func _ensure_dirs() -> void:
	for d in ["res://assets/config", "res://assets/audio", "res://data",
			"res://data/radicals", "res://data/structures"]:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("MO: 保存失败 %s (%d)" % [path, err])
	else:
		print("  + ", path)


func _gen_asset_config() -> void:
	var path := "res://assets/config/asset_config.tres"
	if ResourceLoader.exists(path):
		print("  = 已存在，跳过:", path)
		return
	_save(AssetConfig.new(), path)


func _gen_balance() -> void:
	var path := "res://data/balance.tres"
	if ResourceLoader.exists(path):
		print("  = 已存在，跳过:", path)
		return
	_save(BalanceData.new(), path)


func _gen_radical_library() -> void:
	var path := "res://data/radical_library.tres"
	if ResourceLoader.exists(path):
		print("  = 已存在，跳过:", path)
		return

	var defs: Array = [
		# id, 偏旁, 组成字, 位置, 类型, 名称, 正面, 代价, 颜色, 数值
		["mo_xin", "心", "慕", "bottom", RadicalData.EffectType.PASSIVE, "暮慕", 
			"磁吸：金币与掉落物会飞向你", "敌人也会被你牵过来，且你移速 -8%",
			Color("#ff9ec4"), {"attract": true, "move_factor": 0.92}],
		["mo_ri", "日", "暮", "bottom", RadicalData.EffectType.PASSIVE, "暮色",
			"你的地面消失速度变慢 40%", "天黑了，视野变暗",
			Color("#ffcf6b"), {"vanish_slow_factor": 1.4, "vision_factor": 0.75}],
		["mo_shi", "饣", "馍", "left", RadicalData.EffectType.INSTANT, "口粮",
			"拾取时立即回复 1 心", "无",
			Color("#ffd9a0"), {"heal_on_pickup": 1.0}],
		["mo_shui", "氵", "漠", "left", RadicalData.EffectType.ACTIVE, "流沙",
			"按 Q 喷出三发水柱，每一发都伤害并击退敌人", "无",
			Color("#7fd8ff"), {"skill_action": "skill_1", "cooldown": 3.0}],
		["mo_tu", "土", "墓", "bottom", RadicalData.EffectType.PASSIVE, "碑",
			"你踩过的方块不再消失（化为碑）", "负重：移速 -15%",
			Color("#c8a97e"), {"vanish_slow_factor": 20.0, "move_factor": 0.85}],
		["mo_yue", "月", "膜", "left", RadicalData.EffectType.PASSIVE, "护膜",
			"受到的伤害减少 40%", "移速 -10%",
			Color("#bfe6c8"), {"damage_taken_factor": 0.6, "move_factor": 0.90}],
	]

	var lib := RadicalLibrary.new()
	var arr: Array[RadicalData] = []
	for d in defs:
		var r := RadicalData.new()
		r.id = d[0]
		r.radical_char = d[1]
		r.composed_char = d[2]
		r.radical_position = d[3]
		r.effect_type = d[4]
		r.display_name = d[5]
		r.description = d[6]
		r.downside = d[7]
		r.tint = d[8]
		var nums: Dictionary = d[9]
		for k in nums.keys():
			r.set(k, nums[k])
		r.synergy_tags = PackedStringArray([r.radical_char])
		var rpath := "res://data/radicals/%s.tres" % r.id
		_save(r, rpath)
		# 重新从磁盘加载，让库里存的是「对外部 .tres 的引用」而不是内嵌副本 ——
		# 这样在编辑器里单独改一个偏旁的 .tres 就会直接生效。
		var reloaded: RadicalData = load(rpath)
		arr.append(reloaded if reloaded != null else r)
	lib.radicals = arr
	_save(lib, path)


## ── 结构（像 MC 那样的小建筑）────────────────────────────
## 网格最后一行 = 玩家身体行（平台顶上面那一格），往上依次 -2 / -3 …
## ⚠️ 最后一行必须左右贯通 —— 玩家只向右走，死路 = 卡死。
## 生成器会自检 ground_row_is_open()，不合法的结构会被运行时跳过。
func _gen_structure_library() -> void:
	var path := "res://data/structure_library.tres"
	if ResourceLoader.exists(path):
		print("  = 已存在，跳过:", path)
		return

	var defs: Array = [
		{
			"id": "hut",
			"name": "小屋",
			"weight": 1.0,
			"grid": PackedStringArray([
				"....#....",
				"..#####..",
				".#######.",
				"#..W.E..#",
				".........",
			]),
		},
		{
			"id": "stall",
			"name": "小摊",
			"weight": 0.7,
			"grid": PackedStringArray([
				"..###..",
				"#.....#",
				"...S...",
			]),
		},
		{
			"id": "tower",
			"name": "高台",
			"weight": 1.0,
			"grid": PackedStringArray([
				"...W...",
				"..####.",
			]),
		},
	]

	var lib := StructureLibrary.new()
	var arr: Array[StructureData] = []
	for d in defs:
		var s := StructureData.new()
		s.id = d["id"]
		s.display_name = d["name"]
		s.weight = d["weight"]
		s.grid = d["grid"]
		s.tags = PackedStringArray([d["id"]])
		if not s.ground_row_is_open():
			push_error("MO: 结构 %s 的地面层没有贯通，会导致玩家卡死。" % s.id)
		var spath := "res://data/structures/%s.tres" % s.id
		_save(s, spath)
		var reloaded: StructureData = load(spath)
		arr.append(reloaded if reloaded != null else s)
	lib.structures = arr
	_save(lib, path)
