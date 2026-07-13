class_name Projectile
extends Node2D
## Enemy lob projectile: arcs under gravity, pops on world contact or timeout.

const GRAVITY := 1400.0
const LIFETIME := 4.0

var velocity := Vector2.ZERO
var color := Color(0.85, 0.6, 0.3)
var radius := 9.0

var _age := 0.0


func _ready() -> void:
	var hitbox := Hitbox.new()
	hitbox.faction = &"enemy"
	hitbox.damage = 1.0
	hitbox.continuous = true
	hitbox.knockback_strength = 240.0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hitbox.add_child(shape)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	var motion := velocity * delta
	# Pop on world contact.
	var space := get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
		global_position, global_position + motion + motion.normalized() * radius, 1))
	if not hit.is_empty():
		queue_free()
		return
	global_position += motion
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius, Color(0.15, 0.1, 0.08), false, 2.0)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, color.lightened(0.35))
