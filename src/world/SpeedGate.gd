class_name SpeedGate
extends StaticBody2D
## Breakable barrier: shatters when the player hits it while dashing fast
## enough. A slightly wider sensor detects the incoming dash before the
## solid body would stop it. Origin = TOP-LEFT.

const BREAK_SPEED := 450.0

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

	var sensor := Area2D.new()
	sensor.collision_layer = 32
	sensor.collision_mask = 2
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = size + Vector2(90, 0)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = size / 2.0
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sensor.body_entered.connect(_on_sensor)


func _on_sensor(body: Node2D) -> void:
	if _broken or not body.is_in_group("player"):
		return
	_try_break(body)


func _physics_process(_delta: float) -> void:
	if _broken:
		return
	# Also poll while the player lingers in the sensor (re-dash attempts).
	for area_body in get_tree().get_nodes_in_group("player"):
		var p := area_body as CharacterBody2D
		if p == null:
			continue
		if absf(p.global_position.x - (global_position.x + size.x / 2.0)) < size.x / 2.0 + 100.0 \
				and absf(p.global_position.y - (global_position.y + size.y)) < size.y + 40.0:
			_try_break(p)


func _try_break(p: Node2D) -> void:
	if not (p.has_method("is_dashing") and p.is_dashing()):
		return
	var body := p as CharacterBody2D
	if body == null or absf(body.velocity.x) < BREAK_SPEED:
		return
	_broken = true
	if not break_flag.is_empty():
		GameState.set_flag(break_flag)
	Events.sfx_requested.emit(&"break")
	Events.screenshake_requested.emit(4.0, 0.2)
	Particles.shards(get_parent(), global_position + size / 2.0, Color(0.8, 0.68, 0.3))
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
