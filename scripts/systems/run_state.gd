extends Node
## 当局状态：金币、携带偏旁、槽位数。
## 死亡 / 重开时调用 reset()，全部清空（局内货币不跨局）。

signal coins_changed(coins: int)
signal radicals_changed()

var coins: int = 0
var radicals: Array[RadicalData] = []
var slot_count: int = 2
var stats := {}


func _ready() -> void:
	slot_count = Balance.d.radical_slots_base


func reset() -> void:
	coins = 0
	radicals.clear()
	slot_count = Balance.d.radical_slots_base + int(MetaState.get_upgrade("slots"))
	coins_changed.emit(coins)
	radicals_changed.emit()


func add_coins(n: int) -> void:
	coins = maxi(coins + n, 0)
	coins_changed.emit(coins)


func has_room() -> bool:
	return radicals.size() < slot_count


## 尝试放入偏旁。满了则替换掉最后一个（后续可做成 UI 选择）。
func add_radical(r: RadicalData) -> bool:
	if has_room():
		radicals.append(r)
	else:
		radicals[radicals.size() - 1] = r
	radicals_changed.emit()
	return true


func has_radical_id(id: String) -> bool:
	for r in radicals:
		if r.id == id:
			return true
	return false


func has_attract() -> bool:
	for r in radicals:
		if r.attract:
			return true
	return false


func find_active_skill(action: String) -> RadicalData:
	for r in radicals:
		if r.effect_type == RadicalData.EffectType.ACTIVE and r.skill_action == action:
			return r
	return null
