@tool
extends Node2D
## A decorative clock face drawn in the same style as the Parlor furniture.

const BRASS := Color(0.82, 0.64, 0.28)
const WOOD := Color(0.21, 0.10, 0.12)
const RADIUS := 18.0

@export var hand_angle := -0.65:
	set(value):
		hand_angle = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, WOOD, true, -1.0, true)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, BRASS, 2.0, true)
	for tick in 12:
		var direction := Vector2.from_angle(tick * TAU / 12.0)
		draw_line(direction * (RADIUS - (6.0 if tick % 3 == 0 else 4.0)),
				direction * (RADIUS - 2.0), BRASS, 1.2, true)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(hand_angle) * 8.0, BRASS, 2.0, true)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(hand_angle + 1.9) * 12.0, BRASS, 1.5, true)
	draw_circle(Vector2.ZERO, 2.0, BRASS, true, -1.0, true)
