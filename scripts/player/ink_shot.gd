class_name InkShot
extends Area2D
## 主角发射的「墨点」投射物。也复用作「漠」的水柱。
## 注意：setup() 必须在 add_child() 之前调用（_ready 里要用到 size）。

var dir := Vector2.RIGHT
var speed := 640.0
var damage := 1.0
var life := 0.5
var size := 9.0
var color := Color.WHITE
var knockback := 160.0


func setup(p_dir: Vector2, p_damage: float, p_speed: float, p_life: float,
		p_size: float, p_color: Color, p_knockback: float = 160.0) -> void:
	dir = p_dir.normalized()
	damage = p_damage
	speed = p_speed
	life = p_life
	size = p_size
	color = p_color
	knockback = p_knockback


func _ready() -> void:
	collision_layer = 8
	collision_mask = 4
	monitoring = true
	z_index = 5
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = size
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("hit"):
		body.hit(damage, dir * knockback)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, size, Color(color.r, color.g, color.b, 0.85))
	draw_circle(Vector2.ZERO, size * 0.45, Color(1, 1, 1, 0.9))
	draw_arc(Vector2.ZERO, size, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.5), 2.0)
