class_name Door
extends Area2D
## Zone exit. Auto-triggers when the player enters. Optionally locked behind
## a flag (e.g. a boss defeat) — locked doors render a barred visual and a
## label instead of transporting. Origin = center of the doorway.

@export var target_zone_path: String
@export var target_spawn: String = "Default"
@export var required_flag: String = ""
@export var label_text: String = ""
@export var doorway_size := Vector2(72, 110)

var _cooldown := 0.0


func _ready() -> void:
	collision_layer = 32
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = doorway_size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	if not label_text.is_empty():
		var label := Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7, 0.9))
		label.position = Vector2(-doorway_size.x, -doorway_size.y / 2.0 - 34.0)
		label.custom_minimum_size = Vector2(doorway_size.x * 2.0, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)


func is_open() -> bool:
	return required_flag.is_empty() or GameState.has_flag(required_flag)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0 or not body.is_in_group("player"):
		return
	if not is_open():
		Events.sfx_requested.emit(&"locked")
		return
	_cooldown = 1.0
	Events.sfx_requested.emit(&"door")
	Events.zone_change_requested.emit(target_zone_path, target_spawn)


func _draw() -> void:
	var half := doorway_size / 2.0
	var frame := Rect2(-half, doorway_size)
	var open := is_open()
	var fill := Color(0.1, 0.09, 0.08, 0.85) if open else Color(0.16, 0.07, 0.07, 0.9)
	draw_rect(frame, fill)
	draw_rect(frame, Color(0.85, 0.7, 0.4) if open else Color(0.5, 0.3, 0.3), false, 4.0)
	if open:
		# Inviting glow arch.
		draw_circle(Vector2(0, -half.y * 0.25), 13.0, Color(0.95, 0.85, 0.5, 0.5))
	else:
		# Bars.
		for i in 3:
			var x := -half.x + doorway_size.x * (0.25 + 0.25 * i)
			draw_line(Vector2(x, -half.y + 6), Vector2(x, half.y - 6), Color(0.55, 0.45, 0.4), 5.0)
