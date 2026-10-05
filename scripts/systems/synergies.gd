class_name Synergies
extends RefCounted
## 组合技：同时携带特定的几个字时，叠加额外效果。
##
## 判定只按"携带了哪些字"来做（不看顺序），所以组合技的发现感来自"凑齐"。
## 新增一条组合技：在 LIST 里加一行即可，不用改别处。

## req: 需要的字 id 列表
## 效果通过 sets 里的开关表达，由 Player.recalc_stats 应用（见 apply）
const LIST := [
	{
		"id": "mumu", "name": "暮慕", "req": ["mo_xin", "mo_ri"],
		"desc": "黑暗中吸来的东西会发光：视野补正，磁吸范围 +60%",
		"vision_reset": true, "attract_mul": 1.6, "move_reset": true,
	},
	{
		"id": "shamu", "name": "暮沙", "req": ["mo_shui", "mo_ri"],
		"desc": "水柱从三发变成五发，且命中回血",
		"water_count": 5, "water_heals": true,
	},
	{
		"id": "beilin", "name": "碑林", "req": ["mo_tu", "mo_li"],
		"desc": "碑立得住你了：移速不再被拖慢",
		"move_reset": true,
	},
	{
		"id": "mochan", "name": "暮蝉", "req": ["mo_chong", "mo_ri"],
		"desc": "蝉鸣不歇：跳跃力度 +25%",
		"jump_mul": 1.25,
	},
	{
		"id": "zhongjian", "name": "重剑", "req": ["mo_jin", "mo_tu"],
		"desc": "镆锋带土：攻击力 +50%，且墨点能打碎方块",
		"attack_mul": 1.5, "breaks_blocks": true,
	},
	{
		"id": "mushou", "name": "慕摸", "req": ["mo_xin", "mo_shou"],
		"desc": "伸手一摸，什么都吸得过来：攻击力 +40%",
		"attack_mul": 1.4,
	},
]

static var _last_active: Array = []


static func active(ids: Array) -> Array:
	var out: Array = []
	for s in LIST:
		var ok := true
		for need in s["req"]:
			if not ids.has(need):
				ok = false
				break
		if ok:
			out.append(s)
	return out


## 把组合技的效果应用到主角属性上
static func apply(p: Player, ids: Array) -> void:
	var act := active(ids)
	for s in act:
		if s.get("vision_reset", false):
			p.vision_factor = 1.0
		if s.get("move_reset", false):
			p.move_factor = maxf(p.move_factor, 0.95)
		if s.has("attract_mul"):
			p.attract_radius_mul = float(s["attract_mul"])
		if s.has("water_count"):
			p.water_count = int(s["water_count"])
		if s.get("water_heals", false):
			p.water_heals = true
		if s.has("jump_mul"):
			p.jump_factor *= float(s["jump_mul"])
		if s.has("attack_mul"):
			p.attack_factor *= float(s["attack_mul"])
		if s.get("breaks_blocks", false):
			p.attack_breaks_blocks = true
	# 新凑出一组时给个提示
	var names: Array = []
	for s in act:
		names.append(String(s["id"]))
	for s in act:
		if not _last_active.has(String(s["id"])):
			_announce("组合技「%s」：%s" % [s["name"], s["desc"]])
	_last_active = names


static func _announce(text: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var main := tree.get_first_node_in_group("main")
	if main != null and main.has_method("announce_text"):
		main.announce_text(text, true)


static func describe_all() -> Array:
	var out: Array = []
	for s in LIST:
		out.append("%s（%s）" % [s["name"], s["desc"]])
	return out
