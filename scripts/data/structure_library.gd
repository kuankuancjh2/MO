class_name StructureLibrary
extends Resource
## 结构总表。放在 res://data/structure_library.tres（导出时也能安全加载）。

@export var structures: Array[StructureData] = []


func find_by_id(id: String) -> StructureData:
	for s in structures:
		if s.id == id:
			return s
	return null


## 生成时用：按格坐标的确定性随机挑一个结构（保证同一槽位永远同一个结构）
func pick(deterministic_rand: float) -> StructureData:
	var usable := usable_list()
	if usable.is_empty():
		return null
	var total := 0.0
	for s in usable:
		total += maxf(s.weight, 0.001)
	var t := clampf(deterministic_rand, 0.0, 0.9999) * total
	for s in usable:
		t -= maxf(s.weight, 0.001)
		if t <= 0.0:
			return s
	return usable[usable.size() - 1]


## 只返回合法的结构（地面层贯通的）。不合法的会被跳过并警告 —— 那是设计错误。
func usable_list() -> Array[StructureData]:
	var out: Array[StructureData] = []
	for s in structures:
		if not s.ground_row_is_open():
			push_warning("MO: 结构 %s 的地面层不贯通，已跳过（会卡死玩家）。" % s.id)
			continue
		out.append(s)
	return out
