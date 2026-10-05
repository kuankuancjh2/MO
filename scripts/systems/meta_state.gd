extends Node
## 局外状态：魂币 + 已购全局成长。跨局持久化到 user://mo_save.json。

const SAVE_PATH := "user://mo_save.json"

signal souls_changed(souls: int)

var souls: int = 0
var upgrades: Dictionary = {}   ## id -> level
var traits: Dictionary = {}     ## 永久特性，如 {"double_jump": true}
var best_layer: int = 0


func _ready() -> void:
	load_game()


func get_upgrade(id: String) -> int:
	return int(upgrades.get(id, 0))


## ── 永久特性（拿到一次就永久生效，跨局保留）──────────
func has_trait(name: String) -> bool:
	return bool(traits.get(name, false))


func unlock_trait(name: String) -> void:
	if has_trait(name):
		return
	traits[name] = true
	save_game()


func add_souls(n: int) -> void:
	souls = maxi(souls + n, 0)
	souls_changed.emit(souls)
	save_game()


func buy(id: String, cost: int, max_level: int) -> bool:
	var lv := get_upgrade(id)
	if lv >= max_level:
		return false
	if souls < cost:
		return false
	souls -= cost
	upgrades[id] = lv + 1
	souls_changed.emit(souls)
	save_game()
	return true


func report_layer(layer: int) -> void:
	if layer > best_layer:
		best_layer = layer
		save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"souls": souls,
		"upgrades": upgrades,
		"traits": traits,
		"best_layer": best_layer,
	}, "\t"))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		souls = int(parsed.get("souls", 0))
		best_layer = int(parsed.get("best_layer", 0))
		var up: Variant = parsed.get("upgrades", {})
		if up is Dictionary:
			upgrades = up
		var tr: Variant = parsed.get("traits", {})
		if tr is Dictionary:
			traits = tr
