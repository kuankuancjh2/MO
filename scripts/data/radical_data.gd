class_name RadicalData
extends Resource
## 一个「偏旁 -> 字」的定义。全部能力都由数据描述，逻辑层只读数据。
##
## 设计约定：
## 正面收益和副作用共用同一套「数值因子」字段（1.0 = 无影响），
## 所以 1.0 以上既可以是好处也可以是坏处，由具体语义决定，逻辑层不需要分两套。

enum EffectType {
	INSTANT,  ## 拿到立刻触发一次
	ACTIVE,   ## 占用技能键，按键释放，有 CD
	PASSIVE,  ## 只要携带就常驻生效
}

@export var id: String = ""
@export var radical_char: String = ""            ## 偏旁，如 "心"
@export var composed_char: String = "莫"          ## 组成的字，如 "慕"
@export var radical_position: String = "bottom"  ## "bottom" / "left"
@export var effect_type: EffectType = EffectType.PASSIVE
@export var display_name: String = ""
@export var description: String = ""             ## 正面效果（给玩家看）
@export var downside: String = ""                ## 副作用（给玩家看）
@export var tint: Color = Color("#8fd0ff")

@export_group("数值因子")
@export var vanish_slow_factor: float = 1.0   ## >1 你的地面消失更慢
@export var move_factor: float = 1.0          ## <1 移速变慢
@export var damage_taken_factor: float = 1.0  ## <1 受伤更少
@export var vision_factor: float = 1.0        ## <1 视野变暗
@export var attack_factor: float = 1.0        ## >1 攻击更强
@export var attack_cooldown_factor: float = 1.0  ## >1 攻击更慢
@export var jump_factor: float = 1.0          ## >1 跳得更高
@export var attract: bool = false             ## 磁吸（金币飞向你 / 敌人也漂向你）
@export var heal_on_pickup: float = 0.0       ## 拾取时立即回血
@export var regen_period: float = 0.0         ## >0 = 每隔这么多秒回 1 心

@export_group("永久特性")
## 不为空则永久解锁一个特性（写进存档，之后每局都生效）
## 目前支持："double_jump"
@export var unlocks_trait: String = ""

@export_group("主动技能")
@export var skill_action: String = ""         ## "skill_1" / "skill_2"
@export var cooldown: float = 0.0

@export_group("组合技")
@export var synergy_tags: PackedStringArray = PackedStringArray()

func label() -> String:
	if display_name != "":
		return display_name
	return "%s + %s = %s" % ["莫", radical_char, composed_char]

func summary() -> String:
	var s := ""
	if description != "":
		s += description
	if downside != "":
		if s != "":
			s += "  "
		s += "（代价：%s）" % downside
	return s
