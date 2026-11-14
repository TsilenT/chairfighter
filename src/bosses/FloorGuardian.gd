extends BossBase
## These guardians share arena coordinates and ownership of their
## rectangular sweep attacks. Each guardian authors its own patterns.

const HAZARD := preload("res://src/bosses/RoyalHazard.gd")
const INK := Color(0.105, 0.083, 0.11)

var _hazards: Array[Node2D] = []


func _ready() -> void:
	contact_while_idle = false
	super._ready()


func _clear_attack() -> void:
	for hazard in _hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	_hazards.clear()
	super._clear_attack()


func floor_point(x: float) -> Vector2:
	return Vector2(clampf(x, arena_rect.position.x + 72.0, arena_rect.end.x - 72.0), arena_rect.end.y)


func player_floor_point() -> Vector2:
	var player := player_node()
	return floor_point(player.global_position.x if player != null else global_position.x)


func add_hazard(center: Vector2, size: Vector2, motion: Vector2, color: Color,
		lifetime: float, warmup := 0.12) -> void:
	var hazard := HAZARD.new()
	hazard.size = size
	hazard.velocity = motion
	hazard.color = color
	hazard.lifetime = lifetime
	hazard.warmup = warmup
	get_parent().add_child(hazard)
	hazard.global_position = center
	_hazards = _hazards.filter(is_instance_valid)
	_hazards.append(hazard)


func lob_to(origin: Vector2, target: Vector2, flight: float, color: Color,
		radius: float, style: StringName) -> void:
	var displacement := target - origin
	var launch := displacement / flight - Vector2(0.0, Projectile.GRAVITY * flight * 0.5)
	spawn_projectile(origin, launch, color, radius, style)


func paint_plate(rect: Rect2, color: Color, thickness := 4.0) -> void:
	draw_rect(rect, color)
	draw_rect(rect, INK, false, thickness)


func paint_eyes(center: Vector2, spread: float, radius: float, gaze: float) -> void:
	for side in [-1.0, 1.0]:
		var socket := center + Vector2(spread * side, 0.0)
		draw_circle(socket, radius + 2.0, INK)
		draw_circle(socket, radius, Color(1.0, 0.95, 0.8))
		draw_circle(socket + Vector2(gaze * radius * 0.32, 1.0), radius * 0.42, INK)


func hit_tint(color: Color) -> Color:
	return color.lerp(Color.WHITE, 0.78) if _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0 else color
