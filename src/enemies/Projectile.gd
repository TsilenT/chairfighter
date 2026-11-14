class_name Projectile
extends Node2D
## Enemy lob projectile: arcs under gravity, pops on world contact or timeout.

const GRAVITY := 1400.0
const LIFETIME := 4.0

var velocity := Vector2.ZERO
var color := Color(0.85, 0.6, 0.3)
var radius := 9.0
var faction: StringName = &"enemy"
var damage := 1.0
var knockback_strength := 240.0
var gravity_scale := 1.0
var visual_style: StringName = &"ball"
var is_player_tray := false

var _age := 0.0
var _hitbox: Hitbox


func _ready() -> void:
	add_to_group("projectiles")
	_hitbox = Hitbox.new()
	_hitbox.faction = faction
	_hitbox.damage = damage
	_hitbox.continuous = true
	_hitbox.knockback_strength = knockback_strength
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	_hitbox.add_child(shape)
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * gravity_scale * delta
	var motion := velocity * delta
	# Pop on world contact.
	var space := get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
		global_position, global_position + motion + motion.normalized() * radius, 1))
	if not hit.is_empty():
		queue_free()
		return
	global_position += motion
	if visual_style == &"tray" and velocity.length_squared() > 1.0:
		rotation = velocity.angle()
	elif visual_style == &"cushion" or visual_style == &"paper" or visual_style == &"yarn":
		rotation = _age * (2.5 if velocity.x >= 0 else -2.5)
	queue_redraw()


func is_hostile_to_player() -> bool:
	return faction == &"enemy"


## Reverse a hostile shot with a little lift so it travels back through the
## arena instead of immediately burying itself in the floor.
func deflect(horizontal_hint: float) -> void:
	if not is_hostile_to_player():
		return
	faction = &"player"
	if _hitbox != null:
		_hitbox.faction = faction
	var speed := maxf(520.0, velocity.length() * 1.15)
	var outgoing := -velocity.normalized()
	if outgoing == Vector2.ZERO:
		outgoing = Vector2(signf(horizontal_hint), -0.3)
	if absf(outgoing.x) < 0.25:
		outgoing.x = signf(horizontal_hint) * 0.45
	outgoing.y = minf(outgoing.y, -0.22)
	velocity = outgoing.normalized() * speed
	color = color.lightened(0.25)
	queue_redraw()


func _draw() -> void:
	var outline := Color(0.15, 0.1, 0.08)
	if visual_style == &"tray" or visual_style == &"cushion" or visual_style == &"paper":
		var thickness := 0.42 if visual_style == &"tray" else 0.78
		var points := PackedVector2Array([
			Vector2(-radius, -radius * thickness), Vector2(radius, -radius * thickness),
			Vector2(radius * 0.8, radius * thickness), Vector2(-radius * 0.8, radius * thickness),
		])
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, outline, 2.0, true)
		if visual_style == &"paper":
			for offset in [-0.31, 0.13]:
				draw_line(Vector2(-radius * 0.55, radius * offset),
						Vector2(radius * 0.45, radius * offset), color.darkened(0.47), 1.8, true)
		else:
			draw_line(Vector2(-radius * 0.65, -radius * 0.12),
					Vector2(radius * 0.65, -radius * 0.12), color.lightened(0.35), 2.0, true)
	elif visual_style == &"wave":
		draw_arc(Vector2.ZERO, radius, PI, TAU, 12, outline, 6.0, true)
		draw_arc(Vector2.ZERO, radius, PI, TAU, 12, color, 3.0, true)
		draw_line(Vector2(-radius, 1), Vector2(radius, 1), color, 3.0, true)
	else:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius, outline, false, 2.0)
		if visual_style == &"yarn":
			for offset in [-0.4, 0.0, 0.4]:
				draw_line(Vector2(-radius * 0.64, radius * (offset - 0.2)),
						Vector2(radius * 0.64, radius * (offset + 0.2)), color.lightened(0.4), 1.8, true)
		else:
			draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, color.lightened(0.35))
