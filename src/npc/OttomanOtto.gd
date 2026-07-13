extends Node2D
## Ottoman Otto — the hub's one flavor NPC. A well-meaning footrest who
## comments on your progress. Speech bubble appears when the player is near;
## his line changes as forms unlock. The protagonist stays silent.

const LINES := {
	0: "Oh! A basic chair, out HERE? The Lounge is thataway. Mind the footstools — they bite shins.",
	1: "You BEAT the Baron?! Try holding K near those golden hooks. I'd do it myself but... no arms.",
	2: "Wheels! Fancy. I hear the Storage Closet wall cracks if you hit it at speed. Not that I've tried. No wheels.",
	3: "You can FOLD?! Unnatural. Magnificent. There's a draft from that hatch past the Lounge door — something regal down there.",
	4: "The King himself... good luck, friend. Sit hard, sit true.",
}

var _bubble: Label
var _player_near := false
var _bob := 0.0


func _ready() -> void:
	_bubble = Label.new()
	_bubble.add_theme_font_size_override("font_size", 17)
	_bubble.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_bubble.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	_bubble.add_theme_constant_override("outline_size", 6)
	_bubble.custom_minimum_size = Vector2(340, 0)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.position = Vector2(-170, -160)
	_bubble.visible = false
	add_child(_bubble)

	var area := Area2D.new()
	area.collision_layer = 32
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(260, 160)
	shape.shape = rect
	shape.position = Vector2(0, -60)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_player_near = true
			_refresh())
	area.body_exited.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_player_near = false
			_refresh())
	Events.form_unlocked.connect(func(_id: StringName) -> void: _refresh())
	Events.boss_defeated.connect(func(_id: StringName) -> void: _refresh())


func _refresh() -> void:
	var stage: int = GameState.unlocked_forms.size() - 1
	if GameState.has_flag("boss_king_defeated"):
		stage = 4
	_bubble.text = LINES.get(clampi(stage, 0, 4), LINES[0])
	_bubble.visible = _player_near


func _process(delta: float) -> void:
	_bob += delta * 2.0
	queue_redraw()


func _draw() -> void:
	var plush := Color(0.58, 0.42, 0.58)
	var outline := Color(0.15, 0.1, 0.08)
	var squish := 1.0 + 0.03 * sin(_bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squish))
	# Stubby wooden feet.
	draw_rect(Rect2(-24, -8, 8, 8), Color(0.35, 0.26, 0.18))
	draw_rect(Rect2(16, -8, 8, 8), Color(0.35, 0.26, 0.18))
	# Pouf body: rounded cushion with a skirt seam.
	var sb := StyleBoxFlat.new()
	sb.bg_color = plush
	sb.set_corner_radius_all(18)
	sb.border_color = outline
	sb.set_border_width_all(3)
	sb.draw(get_canvas_item(), Rect2(-32, -54, 64, 46))
	draw_line(Vector2(-30, -26), Vector2(30, -26), plush.darkened(0.25), 2.5)
	# Cushion top highlight.
	var top := StyleBoxFlat.new()
	top.bg_color = plush.lightened(0.15)
	top.set_corner_radius_all(14)
	top.draw(get_canvas_item(), Rect2(-27, -52, 54, 12))
	# Button tufts.
	draw_circle(Vector2(-12, -36), 3.0, plush.darkened(0.35))
	draw_circle(Vector2(12, -36), 3.0, plush.darkened(0.35))
	# Kind eyes with brows.
	draw_circle(Vector2(-10, -45), 5.0, Color.WHITE)
	draw_circle(Vector2(10, -45), 5.0, Color.WHITE)
	draw_circle(Vector2(-9, -44), 2.3, outline)
	draw_circle(Vector2(11, -44), 2.3, outline)
	draw_arc(Vector2(-10, -47), 6.0, PI + 0.4, TAU - 0.4, 8, outline, 2.0)
	draw_arc(Vector2(10, -47), 6.0, PI + 0.4, TAU - 0.4, 8, outline, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
