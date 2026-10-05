class_name ShardBurst
extends Node2D
## 方块/字块碎裂时的碎片飞散特效。纯视觉，自毁。

const LIFE := 0.5

var _shards: Array = []   ## [{pos, vel, size, rot, rot_v}]
var _color := Color.WHITE
var _t := 0.0


func setup(center: Vector2, color: Color, count: int, size: float, power: float) -> void:
	position = center
	_color = color
	for i in range(count):
		var a := randf() * TAU
		_shards.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(a), sin(a) - 0.4) * power * randf_range(0.5, 1.3),
			"size": size * randf_range(0.25, 0.5),
			"rot": randf() * TAU,
			"rot_v": randf_range(-8.0, 8.0),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for s in _shards:
		s["vel"] = s["vel"] + Vector2(0, 1400.0 * Balance.px * delta)
		s["pos"] = s["pos"] + s["vel"] * delta
		s["rot"] = s["rot"] + s["rot_v"] * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	var c := Color(_color.r, _color.g, _color.b, _color.a * a)
	for s in _shards:
		draw_set_transform(s["pos"], s["rot"], Vector2.ONE)
		var sz: float = s["size"]
		draw_rect(Rect2(-sz, -sz, sz * 2.0, sz * 2.0), c, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
