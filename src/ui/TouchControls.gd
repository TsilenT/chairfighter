extends CanvasLayer
## On-screen touch controls for phones/tablets (web build included).
## Instanced by Game only when a touchscreen is available. Built entirely in
## code: TouchScreenButtons (native multitouch + action mapping) with
## generated radial textures — no assets.

const R_BIG := 62.0
const R_MED := 50.0
const R_SMALL := 38.0
const MARGIN := 30.0
const ALPHA := 0.38

var _buttons: Dictionary = {}   # name -> TouchScreenButton


func _ready() -> void:
	layer = 9  # under the HUD (10), over the game
	_add("left", "move_left", "◀", Color(0.8, 0.75, 0.7), R_BIG)
	_add("right", "move_right", "▶", Color(0.8, 0.75, 0.7), R_BIG)
	_add("up", "move_up", "▲", Color(0.8, 0.75, 0.7), R_SMALL)
	_add("jump", "jump", "JUMP", Color(0.45, 0.75, 0.5), R_BIG)
	_add("attack", "attack", "ATK", Color(0.85, 0.4, 0.4), R_MED)
	_add("special", "special", "PWR", Color(0.4, 0.6, 0.85), R_MED)
	_add("form", "transform_next", "SWAP", Color(0.8, 0.7, 0.35), R_SMALL)
	_add("pause", "pause", "II", Color(0.6, 0.6, 0.6), R_SMALL * 0.8)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _add(key: String, action: String, label: String, color: Color, radius: float) -> void:
	var btn := TouchScreenButton.new()
	btn.action = action
	btn.texture_normal = _make_texture(color, radius)
	btn.texture_pressed = _make_texture(color.lightened(0.4), radius)
	btn.set_meta("radius", radius)
	add_child(btn)
	var text := Label.new()
	text.text = label
	text.add_theme_font_size_override("font_size", 18 if label.length() <= 2 else 14)
	text.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	text.position = Vector2(0, radius - 12)
	text.custom_minimum_size = Vector2(radius * 2, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_child(text)
	_buttons[key] = btn


func _make_texture(color: Color, radius: float) -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.width = int(radius * 2)
	tex.height = int(radius * 2)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.8, 0.9, 1.0])
	grad.colors = PackedColorArray([
		Color(color.r, color.g, color.b, ALPHA),
		Color(color.r, color.g, color.b, ALPHA),
		Color(color.lightened(0.3).r, color.lightened(0.3).g, color.lightened(0.3).b, minf(ALPHA + 0.25, 1.0)),
		Color(color.r, color.g, color.b, 0.0),
	])
	tex.gradient = grad
	return tex


func _place(key: String, pos: Vector2) -> void:
	var btn: TouchScreenButton = _buttons[key]
	var r: float = btn.get_meta("radius")
	btn.position = pos - Vector2(r, r)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Left cluster: movement.
	_place("left", Vector2(MARGIN + R_BIG, vp.y - MARGIN - R_BIG))
	_place("right", Vector2(MARGIN + R_BIG * 3.3, vp.y - MARGIN - R_BIG))
	_place("up", Vector2(MARGIN + R_BIG * 2.15, vp.y - MARGIN - R_BIG * 2.6))
	# Right cluster: verbs.
	_place("jump", Vector2(vp.x - MARGIN - R_BIG, vp.y - MARGIN - R_BIG))
	_place("attack", Vector2(vp.x - MARGIN - R_BIG * 3.0, vp.y - MARGIN - R_MED))
	_place("special", Vector2(vp.x - MARGIN - R_BIG * 1.9, vp.y - MARGIN - R_BIG * 2.7))
	_place("form", Vector2(vp.x - MARGIN - R_BIG * 3.8, vp.y - MARGIN - R_BIG * 2.4))
	# Corner: pause.
	_place("pause", Vector2(vp.x - MARGIN - R_SMALL, MARGIN + R_SMALL))
