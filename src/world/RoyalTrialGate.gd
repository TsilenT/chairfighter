class_name RoyalTrialGate
extends StaticBody2D
## Final-gauntlet seal. It only opens when the nearby player successfully
## performs the named form special. Player.special_used is emitted by the
## real ability implementation, so pressing K at the wrong time cannot fake
## a clear. Every clear is flag-backed and therefore survives death/reloads.

const PROMPT_RADIUS := 225.0

@export var required_form: StringName = &"armchair"
@export var required_mechanic: StringName = &"grapple"
@export var alternate_mechanic: StringName = &""
@export var prompt_action := "GRAPPLE THE GOLD HOOK"
@export var trial_number := 1
## Taller than a Rocking launch chained into a mid-air Spring Stool pogo, so
## form switching cannot hop over a proof and counterfeit the intended check.
@export var size := Vector2(40.0, 760.0)
@export var activation_radius := 390.0
@export var clear_flag := ""

var _complete := false
var _shape: CollisionShape2D
var _prompt: Label
var _form_def: FormDef
var _bound_player: Node


func _ready() -> void:
	add_to_group("royal_trials")
	collision_layer = 1
	collision_mask = 0
	if clear_flag.is_empty():
		clear_flag = "final_trial_%s" % required_form
	_form_def = load("res://src/forms/%s.tres" % required_form)
	_build_collision()
	_build_prompt()
	if GameState.has_flag(clear_flag):
		_complete = true
		_shape.set_deferred("disabled", true)
	_refresh_prompt()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _bound_player == null or not is_instance_valid(_bound_player):
		_bind_player()
	_update_prompt_visibility()


func is_complete() -> bool:
	return _complete


func accepts(form_id: StringName, mechanic: StringName) -> bool:
	return form_id == required_form and (mechanic == required_mechanic \
			or (alternate_mechanic != &"" and mechanic == alternate_mechanic))


func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_signal("special_used"):
		return
	_bound_player = player
	var callback := Callable(self, "_on_special_used")
	if not player.is_connected("special_used", callback):
		player.connect("special_used", callback)


func _on_special_used(form_id: StringName, mechanic: StringName) -> void:
	if _complete or not accepts(form_id, mechanic) or _bound_player == null:
		return
	if global_position.distance_to((_bound_player as Node2D).global_position) > activation_radius:
		return
	_complete = true
	GameState.set_flag(clear_flag)
	_shape.set_deferred("disabled", true)
	Events.sfx_requested.emit(&"gate_open")
	Events.screenshake_requested.emit(3.0, 0.18)
	Particles.confetti(get_parent(), global_position + Vector2(size.x / 2.0, -size.y * 0.55))
	_refresh_prompt()
	queue_redraw()


func _build_collision() -> void:
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(size.x / 2.0, -size.y / 2.0)
	add_child(_shape)


func _build_prompt() -> void:
	_prompt = Label.new()
	# Keep the instruction inside a ground-level camera view even though the
	# anti-bypass seal itself rises above the top of the screen.
	_prompt.position = Vector2(-130.0, -370.0)
	_prompt.size = Vector2(300.0, 96.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_outline_color", Color(0.08, 0.025, 0.14))
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.visible = false
	add_child(_prompt)


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	var chair_name := String(required_form).capitalize()
	var color := Color(0.96, 0.76, 0.22)
	if _form_def != null:
		chair_name = _form_def.display_name.to_upper()
		color = _form_def.body_color.lightened(0.28)
	if _complete:
		_prompt.visible = false
	else:
		_prompt.text = "PROOF %d · %s\n%s\nK / pad B" % [trial_number, chair_name, prompt_action]
		_prompt.modulate = color


func _update_prompt_visibility() -> void:
	if _prompt == null:
		return
	if _complete or _bound_player == null or not is_instance_valid(_bound_player):
		_prompt.visible = false
		return
	var player := _bound_player as Node2D
	var gate_center_x := global_position.x + size.x * 0.5
	_prompt.visible = absf(player.global_position.x - gate_center_x) <= PROMPT_RADIUS


func _draw() -> void:
	var color := _form_def.body_color if _form_def != null else Color(0.72, 0.54, 0.2)
	if _complete:
		# Cleared seals retract into unmistakable floor/ceiling sockets.
		draw_rect(Rect2(0, -14, size.x, 14), Color(color.r, color.g, color.b, 0.5))
		draw_rect(Rect2(0, -size.y, size.x, 14), Color(color.r, color.g, color.b, 0.28))
		return
	var body := Rect2(0, -size.y, size.x, size.y)
	draw_rect(body, color.darkened(0.62))
	draw_rect(body, color.lightened(0.18), false, 4.0)
	# Eight-point royal seal and inward arrows make the barrier read as a
	# mechanic lock instead of ordinary level geometry.
	var center := Vector2(size.x / 2.0, -size.y / 2.0)
	draw_circle(center, 15.0, Color(0.08, 0.025, 0.14))
	draw_circle(center, 11.0, color.lightened(0.32), false, 3.0)
	for side in [-1.0, 1.0]:
		var y: float = center.y + side * 46.0
		draw_line(Vector2(8, y - 8), Vector2(20, y), color.lightened(0.4), 3.0)
		draw_line(Vector2(20, y), Vector2(8, y + 8), color.lightened(0.4), 3.0)
