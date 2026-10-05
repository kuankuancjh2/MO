class_name RadicalLibrary
extends Resource
## 偏旁总表。放在 res://data/radical_library.tres，导出时也能被安全加载
## （比运行时扫描目录更可靠）。

@export var radicals: Array[RadicalData] = []

func find_by_id(id: String) -> RadicalData:
	for r in radicals:
		if r.id == id:
			return r
	return null

func find_by_composed(ch: String) -> RadicalData:
	for r in radicals:
		if r.composed_char == ch:
			return r
	return null
