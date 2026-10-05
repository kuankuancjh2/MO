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


## 按键释放主动技能
static func cast_active(p: Player, r: RadicalData) -> void:
	match r.id:
		"mo_shui":  # 漠：向前方喷出水柱，伤害并击退敌人
			_cast_mo_shui(p, r)
		_:
			pass


static func _cast_mo_shui(p: Player, r: RadicalData) -> void:
	# 三发水柱，每一发都独立生效（都伤害 + 击退）。没有副作用。
	var base_dir := p.aim_direction()
	for i in range(3):
		var d := base_dir.rotated((i - 1) * 0.16)
		p.shoot(d, 1.0 * p.attack_factor, 720.0, 0.45, 14.0,
			Assets.cfg.color_radical, 320.0)
	Sfx.play("transform")
