extends Node
## 当局状态：金币、当前携带的那个字、以及它的剩余时间。
## 死亡 / 重开时 reset()，全部清空。
##
## ★ 现在**只能带一个偏旁**（取消槽位），而且**所有偏旁都是临时的**：
##   过一段时间自己消散。所以"变字"是节奏，不是永久强化。

signal coins_changed(coins: int)
signal radicals_changed()

## 所有字的存在时间（秒）。想调"一个字能用多久"就改这里。
const RADICAL_TIME := 26.0

var coins: int = 0
var radicals: Array[RadicalData] = []     ## 最多 1 个
var radical_left: float = 0.0
var slot_count: int = 1                   ## 保留字段：始终为 1


func _ready() -> void:
	slot_count = 1


func _process(delta: float) -> void:
	if radicals.is_empty():
		return
	radical_left -= delta
	if radical_left <= 0.0:
		var gone: RadicalData = radicals[0]
		radicals.clear()
		radical_left = 0.0
		radicals_changed.emit()
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("announce_text"):
			main.announce_text("「%s」散了" % gone.composed_char, false)


func reset() -> void:
	coins = 0
	radicals.clear()
	radical_left = 0.0
	slot_count = 1
	coins_changed.emit(coins)
	radicals_changed.emit()


func add_coins(n: int) -> void:
	coins = maxi(coins + n, 0)
	coins_changed.emit(coins)


func current() -> RadicalData:
	return radicals[0] if not radicals.is_empty() else null


## 拿到一个字：**替换**掉当前的字（不做槽位堆叠）
func add_radical(r: RadicalData) -> bool:
	if r == null:
		return false
	radicals.clear()
	radicals.append(r)
	radical_left = RADICAL_TIME
	radicals_changed.emit()
	return true


## 延长当前字的剩余时间
func extend_radical(seconds: float) -> void:
	if radicals.is_empty():
		return
	radical_left += seconds
	radicals_changed.emit()


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
