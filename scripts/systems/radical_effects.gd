class_name RadicalEffects
extends RefCounted
## 偏旁效果的分发处。
##
## 设计：属性类效果全部由 RadicalData 的数值因子描述（见 Player.recalc_stats），
## 这里只处理「一次性」和「主动技能」这两种需要额外逻辑的效果。
## 新增偏旁时：先看能不能纯数据表达；不能，再在这里加一个分支。

## 拾取瞬间（INSTANT 类型 + 任何 Pickup 时效果）
## 纯数值型的立即效果（比如回血）由 RadicalData 的字段描述，这里不用写；
## 只有需要额外逻辑的才在这里加分支。
static func on_pickup(p: Player, r: RadicalData) -> void:
	if r.heal_on_pickup > 0.0:
		p.heal(r.heal_on_pickup)
	match r.id:
		_:
			pass


static func cast_active(p: Player, r: RadicalData) -> void:
	match r.id:
		"mo_shui":
			_cast_mo_shui(p, r)
		"mo_shou":   # 摸：把附近的金币和偏旁一把抓过来
			_cast_mo_shou(p, r)
		_:
			pass


## 漠：向前方喷出水柱。默认三发，凑出「暮沙」组合技变五发。
static func _cast_mo_shui(p: Player, r: RadicalData) -> void:
	var base_dir := p.aim_direction()
	var n := maxi(p.water_count, 1)
	for i in range(n):
		var ang := 0.0
		if n > 1:
			ang = (float(i) / float(n - 1) - 0.5) * 0.52
		p.shoot(base_dir.rotated(ang), 1.0 * p.attack_factor, 720.0, 0.45, 14.0,
			Assets.cfg.color_radical, 320.0)
	Sfx.play("transform")
	if p.water_heals:
		p.heal(1.0)


## 摸：抓取 —— 把附近的掉落物拉向自己
static func _cast_mo_shou(p: Player, _r: RadicalData) -> void:
	var parent := p.get_parent()
	if parent == null:
		return
	var pulled := 0
	for c in parent.get_children():
		if c is Coin or c is RadicalPickup:
			var d: Vector2 = (c as Node2D).global_position - p.global_position
			if d.length() < 460.0:
				(c as Node2D).global_position = p.global_position + d.normalized() * 30.0
				pulled += 1
	Sfx.play("coin")
	var main := get_main()
	if main != null and pulled == 0:
		main.announce_text("摸了个空")


static func get_main() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("main")
