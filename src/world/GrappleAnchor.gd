class_name GrappleAnchor
extends Node2D
## Hook point for the Armchair grapple. Group: grapple_anchors.

var _pulse := 0.0


func _ready() -> void:
	add_to_group("grapple_anchors")


func _process(delta: float) -> void:
	_pulse += delta * 3.0
	queue_redraw()


func _draw() -> void:
	var gold := Color(0.95, 0.78, 0.3)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 20, gold, 4.0)
	draw_circle(Vector2.ZERO, 5.0, gold.darkened(0.2))
	# Soft pulse so players read it as interactive.
	var a := 0.25 + 0.15 * sin(_pulse)
	draw_arc(Vector2.ZERO, 20.0 + 3.0 * sin(_pulse), 0.0, TAU, 24, Color(gold.r, gold.g, gold.b, a), 2.0)
