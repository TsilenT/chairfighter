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
	var plush := Color(0.55, 0.4, 0.55)
	var outline := Color(0.15, 0.1, 0.08)
	var squish := 1.0 + 0.03 * sin(_bob)
	# Round ottoman body.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squish))
	draw_circle(Vector2(0, -30), 34.0, plush)
	draw_circle(Vector2(0, -30), 34.0, outline, false, 3.0)
	draw_rect(Rect2(-34, -30, 68, 30), plush)
	draw_rect(Rect2(-34, -2, 68, 2), outline)
	# Button tufts.
	draw_circle(Vector2(-12, -38), 3.0, plush.darkened(0.3))
	draw_circle(Vector2(12, -38), 3.0, plush.darkened(0.3))
	# Kind eyes.
	draw_circle(Vector2(-10, -52), 5.0, Color.WHITE)
	draw_circle(Vector2(10, -52), 5.0, Color.WHITE)
	draw_circle(Vector2(-9, -51), 2.3, outline)
	draw_circle(Vector2(11, -51), 2.3, outline)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
