extends RefCounted
## Shared menu typography and states for mouse, touch, and gamepad.

static func button(label: String) -> Button:
	var item := Button.new()
	item.text = label
	item.custom_minimum_size = Vector2(0, 62 if GameState.touch_controls else 52)
	item.add_theme_font_size_override("font_size", 21)
	item.add_theme_color_override("font_color", Color("#fff1d9"))
	item.add_theme_color_override("font_hover_color", Color("#fff9ec"))
	item.add_theme_color_override("font_focus_color", Color("#fff9ec"))
	item.add_theme_color_override("font_disabled_color", Color("#9d8d9a"))
	item.add_theme_stylebox_override("normal", panel(Color("#392b46"), Color("#655473"), 1, 9))
	item.add_theme_stylebox_override("hover", panel(Color("#503960"), Color("#d29c65"), 2, 9))
	item.add_theme_stylebox_override("pressed", panel(Color("#563446"), Color("#f8c783"), 2, 9))
	item.add_theme_stylebox_override("disabled", panel(Color("#251e31"), Color("#342a3e"), 1, 9))
	item.add_theme_stylebox_override("focus", panel(Color.TRANSPARENT, Color("#ffd48b"), 3, 9))
	return item


static func panel(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box


static func label(value: String, font_size: int, color := Color("#d7c9d2")) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item
