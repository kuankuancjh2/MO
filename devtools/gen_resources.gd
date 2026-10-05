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
			"你的地面消失速度变慢 40%", "天黑了：只有你周围一小圈看得见",
			Color("#ffcf6b"), {"vanish_slow_factor": 1.4, "vision_factor": 0.35}],
		["mo_shi", "饣", "馍", "left", RadicalData.EffectType.INSTANT, "口粮",
			"拾取时立即回复 1 心", "无",
			Color("#ffd9a0"), {"heal_on_pickup": 1.0}],
		["mo_shui", "氵", "漠", "left", RadicalData.EffectType.ACTIVE, "流沙",
			"按 Q 喷出三发水柱，每一发都伤害并击退敌人", "无",
			Color("#7fd8ff"), {"skill_action": "skill_1", "cooldown": 3.0}],
		["mo_tu", "土", "墓", "bottom", RadicalData.EffectType.PASSIVE, "碑",
			"你踩过的方块消失得慢很多（6 倍）", "负重：移速 -15%",
			Color("#c8a97e"), {"vanish_slow_factor": 6.0, "move_factor": 0.85}],
		["mo_yue", "月", "膜", "left", RadicalData.EffectType.PASSIVE, "护膜",
			"受到的伤害减少 40%", "移速 -10%",
			Color("#bfe6c8"), {"damage_taken_factor": 0.6, "move_factor": 0.90}],
		["mo_chong", "虫", "蟆", "left", RadicalData.EffectType.PASSIVE, "蝉蜕",
			"跳得更高，并**永久**解锁二段跳（特性，跨局保留）", "无",
			Color("#a8e06a"), {"jump_factor": 1.08, "unlocks_trait": "double_jump"}],
		["mo_shou", "扌", "摸", "left", RadicalData.EffectType.ACTIVE, "探囊",
			"按 E 把附近的金币和偏旁一把抓过来", "无",
			Color("#ffb0d0"), {"skill_action": "skill_2", "cooldown": 8.0}],
		["mo_cao", "艹", "蘑", "bottom", RadicalData.EffectType.PASSIVE, "菌生",
			"拾取时回 1 心，且每 18 秒自动回 1 心", "移速 -5%",
			Color("#c9e8a0"), {"heal_on_pickup": 1.0, "regen_period": 18.0, "move_factor": 0.95}],
		["mo_yan", "讠", "谟", "left", RadicalData.EffectType.PASSIVE, "谋",
			"看得见藏起来的字（藏字的砖会发亮），且地面消失更慢", "无",
			Color("#9fd8d0"), {"vanish_slow_factor": 1.1}],
		["mo_jin", "钅", "镆", "left", RadicalData.EffectType.PASSIVE, "锋",
			"攻击力 +80%", "出招更慢（冷却 +35%）",
			Color("#d8d0ff"), {"attack_factor": 1.8, "attack_cooldown_factor": 1.35}],
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
			"id": "ladder_tower",
			"name": "梯塔",
			"weight": 0.9,
			# 梯子是全作唯一能"向上爬"的东西：爬到顶上往右一踏就是平台
			"grid": PackedStringArray([
				".L......",
				".L######",
				".L......",
				".L......",
				".L......",
				"........",
			]),
		},
		{
			"id": "hut",
			"name": "小屋",
			"weight": 1.0,
			# R 屋顶 / V 窗 / # 墙；地面层贯通
			"grid": PackedStringArray([
				"...RRR...",
				".#######.",
				"##V###V##",
				".........",
			]),
		},
		{
			"id": "castle",
			"name": "城门",
			"weight": 0.8,
			# 上排雉堞 + 城墙 + 地面上的拱门（A 非实心，可从中间穿过去）
			"grid": PackedStringArray([
				"#.#.#.#.#.#",
				"###########",
				"....A......",
			]),
		},
		{
			"id": "tower",
			"name": "塔",
			"weight": 0.7,
			"grid": PackedStringArray([
				".RRR.",
				".TTT.",
				".TTT.",
				".TTT.",
				".....",
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
			"id": "arch",
			"name": "悬字台",
			"weight": 1.0,
			"grid": PackedStringArray([
				"..###..",
				"...W...",
				".......",
			]),
		},
		{
			"id": "gate",
			"name": "拱门",
			"weight": 0.9,
			"grid": PackedStringArray([
				".#####.",
				"#.....#",
				"#..W..#",
				".......",
			]),
		},
		{
			"id": "colonnade",
			"name": "柱廊",
			"weight": 0.9,
			"grid": PackedStringArray([
				"C..C..C..C..C",
				".............",
			]),
		},
		{
			"id": "grave",
			"name": "碑",
			"weight": 1.0,
			"grid": PackedStringArray([
				"..C..",
				"..W..",
				".....",
			]),
		},
		{
			"id": "market",
			"name": "集市",
			"weight": 0.5,
			"grid": PackedStringArray([
				"..#######..",
				"#.........#",
				"..F.S.S.F..",
			]),
		},
		{
			"id": "hall",
			"name": "有之殿",
			"weight": 0.22,
			"grid": PackedStringArray([
				".RRRRRRRRRRR.",
				"#############",
				"#V........V#",
				"#....B.....#",
				".............",
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
