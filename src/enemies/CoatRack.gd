extends EnemyBase
## Stationary lobber: tosses cushions in an arc toward the player when in
## range. The player's one "artillery" threat.

const ProjectileScript := preload("res://src/enemies/Projectile.gd")

@export var lob_range := 520.0
@export var lob_interval := 2.2

var _cooldown := 1.0


func _ready() -> void:
	max_health = 5.0
	move_speed = 0.0
	body_size = Vector2(30, 96)
	super._ready()


func _ai(delta: float) -> void:
	velocity.x = 0.0
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	if absf(to_player.x) > lob_range or absf(to_player.y) > 400.0:
		return
	_cooldown = lob_interval
	var proj: Node2D = ProjectileScript.new()
	proj.global_position = global_position + Vector2(0, -float(body_size.y) + 10.0)
	# Simple ballistic lead: fixed flight time, solve initial velocity.
	var t := 0.9
	proj.velocity = Vector2(to_player.x / t, to_player.y / t - 0.5 * 1400.0 * t)
	get_parent().add_child(proj)
	Events.sfx_requested.emit(&"lob")


func _draw_body() -> void:
	var outline := Color(0.15, 0.1, 0.08)
	var wood := skin_color.darkened(0.1)
	# Pole.
	draw_rect(Rect2(-4, -body_size.y, 8, body_size.y), wood)
	draw_rect(Rect2(-4, -body_size.y, 8, body_size.y), outline, false, 2.0)
	# Base feet.
	draw_rect(Rect2(-18, -6, 36, 6), wood.darkened(0.2))
	# Hooks.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(0, -body_size.y + 12), Vector2(side * 16, -body_size.y + 4), wood, 5.0)
	# Grumpy eye.
	draw_circle(Vector2(0, -body_size.y + 22), 5.0, Color.WHITE)
	draw_circle(Vector2(0, -body_size.y + 22), 2.4, outline)
