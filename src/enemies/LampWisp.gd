extends EnemyBase
## Floating lamp spirit. Bobs around its home point; swoops when the player
## comes near, then drifts back.

@export var swoop_range := 220.0
@export var swoop_speed := 240.0

var _home := Vector2.ZERO
var _t := 0.0
var _swooping := false


func _ready() -> void:
	max_health = 3.0
	gravity_on = false
	move_speed = 80.0
	body_size = Vector2(34, 34)
	super._ready()
	_home = global_position


func _ai(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var target := _home + Vector2(sin(_t * 1.4) * 44.0, sin(_t * 2.3) * 22.0)
	_swooping = false
	if player != null and global_position.distance_to(player.global_position) < swoop_range:
		target = player.global_position + Vector2(0, -30)
		_swooping = true
	var speed := swoop_speed if _swooping else move_speed
	velocity = (target - global_position).limit_length(speed)


func _draw_body() -> void:
	var glow := Color(1.0, 0.85, 0.45, 0.35)
	var shade := skin_color
	var outline := Color(0.15, 0.1, 0.08)
	draw_circle(Vector2(0, -17), 22.0, glow)
	# Lampshade cone.
	var pts := PackedVector2Array([Vector2(-16, -12), Vector2(16, -12), Vector2(8, -30), Vector2(-8, -30)])
	draw_colored_polygon(pts, shade)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 2.5)
	# Bulb.
	draw_circle(Vector2(0, -8), 6.0, Color(1.0, 0.95, 0.7))
	# Eye.
	draw_circle(Vector2(0, -20), 4.0, Color.WHITE)
	draw_circle(Vector2(0, -20), 2.0, outline)
