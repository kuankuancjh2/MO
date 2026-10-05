extends Node
## 手感/平衡参数单例。优先读 res://data/balance.tres，缺失则用代码默认值。

const CONFIG_PATH := "res://data/balance.tres"

var d: BalanceData


func _ready() -> void:
	if ResourceLoader.exists(CONFIG_PATH):
		d = load(CONFIG_PATH) as BalanceData
	if d == null:
		d = BalanceData.new()
		push_warning("MO: data/balance.tres 不存在，使用代码默认参数。")
