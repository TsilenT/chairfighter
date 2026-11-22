@tool
extends Label
## Draw route arrows without depending on glyphs in a platform font.

@export var direction := Vector2.RIGHT:
	set(value):
		direction = value
		queue_redraw()


func _draw() -> void:
	var title := text.get_slice("\n", 0)
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var center := Vector2(width + 14.0, font.get_height(font_size) * 0.5)
	var axis := direction.normalized()
	var tip := center + axis * 6.0
	var side := axis.orthogonal() * 4.0
	var color := get_theme_color("font_color")
	draw_line(center - axis * 6.0, tip, color, 2.0, true)
	draw_polyline(PackedVector2Array([center + side, tip, center - side]), color, 2.0, true)
