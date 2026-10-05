class_name InkShot
extends Area2D
## 投射物。主角的「墨点」、技能的水柱、以及 Boss 吐出的字都用它。
## 注意：setup() 必须在 add_child() 之前调用（_ready 里要用到 size）。

var dir := Vector2.RIGHT
var speed := 640.0
var damage := 1.0
var life := 0.5
var size := 9.0
var color := Color.WHITE
var knockback := 160.0
var hits_player := false       ## true = 打玩家（Boss/敌人弹）；false = 打敌人
var breaks_blocks := false     ## 命中方块也会把它打碎


func setup(p_dir: Vector2, p_damage: float, p_speed: float, p_life: float,
		p_size: float, p_color: Color, p_knockback: float = 160.0,
		p_hits_player: bool = false, p_breaks_blocks: bool = false) -> void:
	dir = p_dir.normalized()
	damage = p_damage
	speed = p_speed
	life = p_life
	size = p_size
	color = p_color
	knockback = p_knockback
	hits_player = p_hits_player
	breaks_blocks = p_breaks_blocks


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2 if hits_player else 4
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
	if hits_player:
		if body is Player:
			(body as Player).take_damage(damage, "enemy")
			queue_free()
		return
	if body is SolidTile:
		if breaks_blocks:
			(body as SolidTile).on_touched(null)
			queue_free()
		return
	if body.has_method("hit"):
		body.hit(damage, dir * knockback)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, size, Color(color.r, color.g, color.b, 0.85))
	draw_circle(Vector2.ZERO, size * 0.45, Color(1, 1, 1, 0.9))
	draw_arc(Vector2.ZERO, size, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.5), 2.0)
