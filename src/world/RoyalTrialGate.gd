class_name RoyalTrialGate
extends StaticBody2D
## A fixture in the King's workshop. Each seal opens when its mechanism is
## physically operated. Cleared fixtures remain open across visits.

const PROMPT_RADIUS := 222.0
const CRAWL_CLEARANCE := 27.0
const GRAPPLE_SWITCH := Vector2(-70, -214)
const CHIME := Vector2(-58, -276)
const PRESSURE_PLATE := Rect2(-104, -8, 80, 8)

@export var required_form: StringName = &"armchair"
@export var required_mechanic: StringName = &"grapple"
@export var prompt_action := "Pull yourself up to the gold latch."
@export var trial_number := 1
@export var size := Vector2(40.0, 760.0)

var clear_flag: String
var _complete := false
var _shape: CollisionShape2D
var _prompt: Label
var _form_def: FormDef
var _player: Player
var _shot: Projectile
var _shot_left := 0.95


func _ready() -> void:
	add_to_group("royal_trials")
	collision_layer = 1
	collision_mask = 0
	clear_flag = "final_trial_%s" % required_form
	_form_def = load("res://src/forms/%s.tres" % required_form)
	_complete = GameState.has_flag(clear_flag)
	_build_collision()
	_build_prompt()
	if not _complete and required_mechanic in [&"spin", &"toss"]:
		_build_target()
	set_physics_process(not _complete)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_bind_player()
	if _player == null or not _player.is_alive():
		_prompt.hide()
		return
	var feet := to_local(_player.global_position)
	_prompt.visible = absf(feet.x) <= PROMPT_RADIUS
	match required_mechanic:
		&"grapple":
			if _player.is_grappling() and feet.distance_to(GRAPPLE_SWITCH) <= 43.0:
				_complete_trial()
		&"dash":
			if _player.is_dashing():
				for i in _player.get_slide_collision_count():
					if _player.get_slide_collision(i).get_collider() == self:
						_complete_trial()
						break
		&"fold":
			if _player.is_folded() and feet.x >= size.x + Player.BODY_WIDTH * 0.5 and absf(feet.y) < 8.0:
				_complete_trial()
		&"brace", &"spin":
			_update_launcher(delta, feet)
		&"pogo":
			if GameState.current_form == required_form and _player.is_using_special(&"pogo") \
					and (feet + Vector2(0, -24)).distance_to(CHIME) <= 36.0:
				_complete_trial()


func is_complete() -> bool:
	return _complete


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.special_used.connect(_on_special_used)
		_player.braced_hit.connect(_on_braced_hit)


func _on_special_used(form_id: StringName, mechanic: StringName) -> void:
	if _complete or form_id != required_form or mechanic != &"slam" or required_mechanic != &"slam":
		return
	var feet := to_local(_player.global_position)
	if absf(feet.y) < 5.0 and feet.x >= PRESSURE_PLATE.position.x and feet.x <= PRESSURE_PLATE.end.x:
		_complete_trial()


func _on_braced_hit(hitbox: Hitbox) -> void:
	if not _complete and required_mechanic == &"brace" and is_instance_valid(_shot) and hitbox.get_parent() == _shot:
		_complete_trial()


func _update_launcher(delta: float, feet: Vector2) -> void:
	if feet.x < -185.0 or feet.x >= -32.0 or absf(feet.y) >= 65.0:
		_shot_left = 0.95
		queue_redraw()
		return
	_shot_left -= delta
	queue_redraw()
	if _shot_left > 0.0:
		return
	_shot_left = 2.0
	if is_instance_valid(_shot):
		_shot.queue_free()
	_shot = Projectile.new()
	_shot.gravity_scale = 0.0
	_shot.color = _form_def.body_color.lightened(0.48)
	_shot.velocity = Vector2(-220, 0)
	_shot.position = Vector2(-12, -31)
	add_child(_shot)
	Events.sfx_requested.emit(&"lob")


func _target_position() -> Vector2:
	return Vector2(-38, -64)


func _build_target() -> void:
	var target := Hurtbox.new()
	target.faction = &"enemy"
	target.position = _target_position()
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = Vector2(34, 68) if required_mechanic == &"spin" else Vector2(30, 34)
	shape.shape = bounds
	target.add_child(shape)
	target.hit_received.connect(_on_target_hit)
	add_child(target)


func _on_target_hit(hitbox: Hitbox) -> void:
	if _complete or hitbox.faction != &"player":
		return
	var projectile := hitbox.get_parent() as Projectile
	if projectile == null:
		return
	var reflected := required_mechanic == &"spin" and projectile == _shot
	var tray := required_mechanic == &"toss" and projectile.is_player_tray
	if reflected or tray:
		projectile.queue_free()
		_complete_trial()


func _complete_trial() -> void:
	if _complete:
		return
	_complete = true
	GameState.set_flag(clear_flag)
	_shape.set_deferred("disabled", true)
	if is_instance_valid(_shot):
		_shot.queue_free()
	set_physics_process(false)
	_prompt.hide()
	Events.sfx_requested.emit(&"gate_open")
	Events.screenshake_requested.emit(3.0, 0.18)
	Particles.confetti(get_parent(), global_position + Vector2(-24.0, -92.0))
	queue_redraw()


func _build_collision() -> void:
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var clearance := CRAWL_CLEARANCE if required_mechanic == &"fold" else 0.0
	rect.size = size - Vector2(0, clearance)
	_shape.shape = rect
	_shape.position = Vector2(size.x / 2.0, -size.y + rect.size.y / 2.0)
	_shape.disabled = _complete
	add_child(_shape)


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.position = Vector2(-223.0, -240.0 if required_mechanic != &"grapple" else -125.0)
	_prompt.size = Vector2(210.0, 74.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_outline_color", Color(0.08, 0.025, 0.14))
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.modulate = _form_def.body_color.lightened(0.58)
	_prompt.text = "%d. %s\n%s" % [trial_number, _form_def.display_name, prompt_action]
	_prompt.hide()
	add_child(_prompt)


func _draw() -> void:
	var color := Color(0.72, 0.54, 0.2)
	if _form_def != null:
		color = _form_def.body_color.lightened(0.32)
	if _complete:
		draw_rect(Rect2(0, -9, size.x, 9), color.darkened(0.3))
		draw_rect(Rect2(0, -size.y, size.x, 14), color.darkened(0.3))
		return
	var clearance := CRAWL_CLEARANCE if required_mechanic == &"fold" else 0.0
	var body := Rect2(0, -size.y, size.x, size.y - clearance)
	draw_rect(body, color.darkened(0.68))
	draw_rect(body, color, false, 3.0)
	for y in range(-660, -92, 52):
		draw_line(Vector2(8, y), Vector2(size.x - 8.0, y + 15), color.darkened(0.25), 2.0)
	match required_mechanic:
		&"grapple":
			_draw_switch(GRAPPLE_SWITCH, color)
		&"brace":
			_draw_launcher(color)
		&"dash":
			draw_polyline(PackedVector2Array([Vector2(15, -105), Vector2(23, -76),
					Vector2(13, -48), Vector2(27, -19), Vector2(20, -4)]), color.lightened(0.3), 4.0)
		&"spin":
			_draw_launcher(color)
			_draw_switch(_target_position() + Vector2(0, -9), color)
		&"fold":
			draw_line(Vector2(-13, -CRAWL_CLEARANCE), Vector2(size.x + 13, -CRAWL_CLEARANCE), color.lightened(0.35), 4.0)
		&"toss":
			_draw_switch(_target_position(), color)
		&"slam":
			draw_rect(PRESSURE_PLATE, color)
			draw_line(PRESSURE_PLATE.position + Vector2(4, 1), Vector2(PRESSURE_PLATE.end.x - 4, -7), color.lightened(0.5), 2.0)
		&"pogo":
			draw_line(CHIME + Vector2(0, -46), CHIME, color.darkened(0.2), 3.0)
			_draw_switch(CHIME, color)


func _draw_switch(center: Vector2, color: Color) -> void:
	draw_line(Vector2(0, center.y), center, color.darkened(0.2), 6.0)
	draw_circle(center, 15.0, color.darkened(0.5))
	draw_circle(center, 13.0, color.lightened(0.35), false, 3.0)
	draw_circle(center, 5.0, color.lightened(0.5))


func _draw_launcher(color: Color) -> void:
	var charge := clampf(1.0 - _shot_left / 0.95, 0.0, 1.0)
	draw_rect(Rect2(-19, -42, 28, 22), color.darkened(0.3))
	draw_circle(Vector2(-16, -31), 8.0, color.lerp(Color(1.0, 0.93, 0.55), charge))
