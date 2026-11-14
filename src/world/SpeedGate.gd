class_name SpeedGate
extends StaticBody2D
## Breakable barrier: a head-on dash must actually strike the solid wall.
## Origin = TOP-LEFT.

@export var size := Vector2(40, 140)
## Optional flag set when broken (for validator/driver assertions).
@export var break_flag: String = ""

var _broken := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	# A wall broken in a previous visit stays broken (flag-keyed).
	if not break_flag.is_empty() and GameState.has_flag(break_flag):
		_broken = true
		shape.set_deferred("disabled", true)
		queue_redraw()
		return

func _physics_process(_delta: float) -> void:
	if _broken:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.is_dashing():
		return
	# move_and_slide can zero the player's velocity on contact. Use the
	# collision normal against the live dash direction instead.
	for i in player.get_slide_collision_count():
		var collision := player.get_slide_collision(i)
		if collision.get_collider() == self and collision.get_normal().x * player.facing < -0.9:
			_break_at(collision.get_position())
			return


func _break_at(contact: Vector2) -> void:
	_broken = true
	if not break_flag.is_empty():
		GameState.set_flag(break_flag)
	Events.sfx_requested.emit(&"break")
	Events.screenshake_requested.emit(4.0, 0.2)
	Particles.shards(get_parent(), contact, Color(0.8, 0.68, 0.3))
	# Leave rubble stubs, drop collision.
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	queue_redraw()


func _draw() -> void:
	if _broken:
		draw_rect(Rect2(0, size.y - 12, 14, 12), Color(0.75, 0.65, 0.3, 0.8))
		draw_rect(Rect2(size.x - 14, size.y - 10, 14, 10), Color(0.75, 0.65, 0.3, 0.8))
		return
	var body_color := Color(0.8, 0.68, 0.3)
	draw_rect(Rect2(Vector2.ZERO, size), body_color.darkened(0.35))
	draw_rect(Rect2(Vector2.ZERO, size), body_color, false, 4.0)
	# Cracks hint + ">>" marks to suggest dashing through.
	draw_line(Vector2(size.x * 0.3, 8), Vector2(size.x * 0.7, size.y * 0.4), body_color.lightened(0.2), 2.0)
	draw_line(Vector2(size.x * 0.7, size.y * 0.4), Vector2(size.x * 0.35, size.y * 0.8), body_color.lightened(0.2), 2.0)
	var mid := size.y / 2.0
	for i in 2:
		var x0 := size.x * 0.25 + i * size.x * 0.3
		draw_line(Vector2(x0, mid - 8), Vector2(x0 + 8, mid), Color(0.2, 0.15, 0.1), 3.0)
		draw_line(Vector2(x0 + 8, mid), Vector2(x0, mid + 8), Color(0.2, 0.15, 0.1), 3.0)
