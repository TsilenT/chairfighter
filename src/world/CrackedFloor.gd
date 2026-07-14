class_name CrackedFloor
extends StaticBody2D
## Breakable floor slab: shatters under a Rocking Chair slam landing (or any
## sufficiently heavy impact — the player calls crack_break()). Origin =
## TOP-LEFT. Group: cracked_floors. Flag-keyed like SpeedGate so a broken
## floor stays broken across revisits.

@export var size := Vector2(128, 24)
@export var break_flag: String = ""

var _broken := false
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("cracked_floors")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)
	if not break_flag.is_empty() and GameState.has_flag(break_flag):
		_broken = true
		_shape.set_deferred("disabled", true)
	queue_redraw()


func top_rect() -> Rect2:
	return Rect2(global_position, size)


func crack_break() -> void:
	if _broken:
		return
	_broken = true
	if not break_flag.is_empty():
		GameState.set_flag(break_flag)
	_shape.set_deferred("disabled", true)
	Events.sfx_requested.emit(&"break")
	Events.screenshake_requested.emit(5.0, 0.25)
	Particles.shards(get_parent(), global_position + size / 2.0, Color(0.5, 0.36, 0.24))
	queue_redraw()


func _draw() -> void:
	if _broken:
		# Splintered stubs at the edges.
		draw_rect(Rect2(0, 4, 16, size.y - 8), Color(0.4, 0.28, 0.18, 0.8))
		draw_rect(Rect2(size.x - 16, 6, 16, size.y - 10), Color(0.4, 0.28, 0.18, 0.8))
		return
	var wood := Color(0.5, 0.36, 0.24)
	draw_rect(Rect2(Vector2.ZERO, size), wood)
	draw_rect(Rect2(0, 0, size.x, 6), wood.lightened(0.15))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.1, 0.07), false, 3.0)
	# Visible cracks.
	var mid := size / 2.0
	draw_line(Vector2(mid.x - 26, 2), Vector2(mid.x - 6, size.y - 3), Color(0.2, 0.12, 0.08), 2.0)
	draw_line(Vector2(mid.x - 6, size.y - 3), Vector2(mid.x + 14, 4), Color(0.2, 0.12, 0.08), 2.0)
	draw_line(Vector2(mid.x + 14, 4), Vector2(mid.x + 30, size.y - 5), Color(0.2, 0.12, 0.08), 1.5)
