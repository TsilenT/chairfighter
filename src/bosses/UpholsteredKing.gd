extends BossBase
## The Upholstered King — final ruler of every seat in the realm.

const FOOTSTOOL_SCRIPT := preload("res://src/enemies/Footstool.gd")
const ROYAL_HAZARD_SCRIPT := preload("res://src/bosses/RoyalHazard.gd")

var _opening_edict := 0
var _edict_window_active := false
var _edict_can_counter := false
var _edict_countered := false
var _edict_escape_proved := false
var _edict_form: StringName = &""
var _edict_mechanics: Array[StringName] = []
var _edict_start_health := -1.0
var _edict_layer: CanvasLayer
var _edict_panel: PanelContainer
var _edict_label: Label
var _special_player: Node


func _ready() -> void:
	boss_id = &"king"
	display_name = "The Upholstered King"
	max_health = 90.0
	unlock_form_id = &""
	body_half_width = 75.0
	body_height = 170.0
	contact_damage = 1.0
	super._ready()
	if is_queued_for_deletion():
		return
	# The King is enormous, so melee naturally overlaps him. Keep the contact
	# hit honest but infrequent enough for the simple demo fighter to trade.
	for child in get_children():
		if child is Hitbox and (child as Hitbox).continuous:
			(child as Hitbox).rehit_interval = 4.5
	_build_edict_ui()


func _on_trigger(body: Node2D) -> void:
	if not GameState.has_all_final_forms():
		_show_edict("AUDIENCE DENIED", "Eight earned chairs must answer the Crown.", Color(0.9, 0.3, 0.28))
		return
	if not GameState.has_completed_final_trials():
		_show_edict("HALL UNANSWERED", "Prove all eight chair specials before approaching the Crown.", Color(0.9, 0.3, 0.28))
		return
	_bind_special_signal(body)
	super._on_trigger(body)
	if active and _edict_panel != null:
		_edict_panel.visible = false


func _on_hit_received(hb: Hitbox) -> void:
	if _edict_window_active:
		# Keep the specific chair + hazard instruction on screen. An accidental
		# primary swing must not replace it with a vague generic warning.
		return
	if _opening_edict < 2:
		# Ordinary swings cannot interrupt the clearly announced response
		# window. Opening proofs repeat until the named response is performed.
		_show_edict("THE CROWN COMMANDS A COUNTER", "The next named chair proof starts momentarily.", Color(0.98, 0.72, 0.22))
		return
	super._on_hit_received(hb)


func _on_player_died() -> void:
	_clear_edict()
	super._on_player_died()


func _bind_special_signal(player: Node) -> void:
	if player == null or not player.has_signal("special_used"):
		return
	_special_player = player
	var callback := Callable(self, "_on_special_used")
	if not player.is_connected("special_used", callback):
		player.connect("special_used", callback)


func _on_special_used(form_id: StringName, mechanic: StringName) -> void:
	if not active or defeated or not _edict_window_active or not _edict_can_counter:
		return
	if form_id != _edict_form or mechanic not in _edict_mechanics:
		return
	_edict_countered = true
	_edict_can_counter = false
	var def: FormDef = load("res://src/forms/%s.tres" % form_id)
	var chair_name := def.display_name.to_upper() if def != null else String(form_id).to_upper()
	_show_edict("RESPONSE SET • %s" % chair_name,
			"Stay clear until the royal attack passes.", Color(0.72, 0.95, 1.0))


func _clear_edict() -> void:
	_edict_window_active = false
	_edict_can_counter = false
	_edict_countered = false
	_edict_escape_proved = false
	_edict_start_health = -1.0
	_edict_form = &""
	_edict_mechanics.clear()
	if _edict_panel != null:
		_edict_panel.visible = false


## Public read-only hooks used by the input-path playthrough. They do not
## advance the fight; the driver still has to transform and perform specials.
func announced_edict_form() -> StringName:
	return _edict_form if _edict_window_active else &""


func current_edict_form() -> StringName:
	# The demo and assistive automation see the requested form only once the
	# corresponding hazard is live; a telegraph-only button tap is not proof.
	return _edict_form if _edict_window_active and _edict_can_counter else &""


func opening_edicts_complete() -> bool:
	return _opening_edict >= 2


func opening_edict_forms() -> Array[StringName]:
	return [&"armchair", &"folding"]


func _patterns() -> Array[Callable]:
	# The audience opens with two deterministic form checks. A missed window
	# repeats after a breather; only the named counter opens ordinary combat.
	if _opening_edict == 0:
		return [_grapple_escape]
	if _opening_edict == 1:
		return [_fold_sweep]
	var list: Array[Callable] = [_royal_smash, _summon_court, _cushion_volley]
	if phase >= 2:
		list.append(_throne_charge)
		list.append(_grapple_escape)
		list.append(_fold_sweep)
	return list


func _on_phase_two() -> void:
	# A royal tantrum, conducted entirely through upholstery.
	hop(Vector2(0, -650.0))


# -- form-response edicts --------------------------------------------------

func _grapple_escape() -> void:
	var countered: bool = await _run_edict(
			&"armchair", [&"grapple"],
			"FLOOR COLLAPSE • ARMCHAIR",
			"Switch to ARMCHAIR, then hold SPECIAL near a gold hook.",
			&"grapple")
	if countered and _opening_edict == 0:
		_opening_edict = 1


func _fold_sweep() -> void:
	var countered: bool = await _run_edict(
			&"folding", [&"fold"],
			"CROWN SWEEP • FOLDING CHAIR",
			"Switch to FOLDING, then tap SPECIAL to duck beneath the beam.",
			&"fold")
	if countered and _opening_edict == 1:
		_opening_edict = 2


func _run_edict(form_id: StringName, mechanics: Array[StringName], title: String,
		hint: String, hazard_kind: StringName) -> bool:
	_edict_form = form_id
	_edict_mechanics = mechanics
	_edict_countered = false
	_edict_escape_proved = false
	_edict_window_active = true
	_edict_can_counter = false
	var def: FormDef = load("res://src/forms/%s.tres" % form_id)
	var cue_color := def.body_color.lightened(0.3) if def != null else Color(0.98, 0.72, 0.22)
	_show_edict(title, hint + "\nREADY — answer after the gold flash.", cue_color)
	await telegraph(0.7)
	if not active or defeated:
		_clear_edict()
		return false
	var response_player := player_node()
	_edict_start_health = response_player.current_health() \
			if response_player != null and response_player.has_method("current_health") else -1.0
	# Spawn first, then accept the form response. This guarantees the player is
	# actually escaping the quake or ducking under the sweep—not cancelling it
	# with an early input during the warning card.
	_spawn_edict_hazard(hazard_kind)
	_edict_can_counter = true
	_show_edict(title, hint + "\nCOUNTER NOW — the attack is live.", cue_color)
	var left := 0.9 if hazard_kind == &"grapple" else 2.2
	while active and not defeated and left > 0.0:
		await get_tree().physics_frame
		if not can_process():
			continue
		if hazard_kind == &"grapple":
			var live_player := player_node()
			if live_player != null and live_player.has_method("is_grappling") \
					and live_player.is_grappling() \
					and live_player.global_position.y <= arena_rect.end.y - 80.0:
				_edict_escape_proved = true
		left -= get_physics_process_delta_time()
	if not active or defeated:
		_clear_edict()
		return false
	_edict_window_active = false
	var succeeded := _edict_countered and _response_survived(hazard_kind)
	if succeeded:
		_confirm_edict_counter(form_id)
	else:
		var missed_hint := "Hold the named safe state until the attack has passed." \
				if _edict_countered else "This proof repeats until you use the named special."
		_show_edict("EDICT UNANSWERED", missed_hint, Color(0.96, 0.46, 0.34))
	await wait(0.65)
	_clear_edict()
	return succeeded


func _response_survived(hazard_kind: StringName) -> bool:
	var player := player_node()
	if player == null or not player.has_method("current_health"):
		return false
	if hazard_kind == &"grapple":
		# A clean response keeps its health. If the carpet grazes the launch frame,
		# accept only a grapple observed above the danger strip while the response
		# was live; merely tapping grapple and remaining on the floor is not proof.
		var unharmed := is_equal_approx(player.current_health(), _edict_start_health)
		return unharmed or _edict_escape_proved
	if not is_equal_approx(player.current_health(), _edict_start_health):
		return false
	return GameState.current_form == &"folding" and player.has_method("is_folded") \
			and player.is_folded()


func _confirm_edict_counter(form_id: StringName) -> void:
	var def: FormDef = load("res://src/forms/%s.tres" % form_id)
	var chair_name := def.display_name.to_upper() if def != null else String(form_id).to_upper()
	_show_edict("COUNTERED • %s" % chair_name,
			"The Crown is staggered — 3 bonus damage!", Color(0.45, 1.0, 0.58))
	Events.sfx_requested.emit(&"boss_hit")
	Events.hitstop_requested.emit(0.1)
	Events.screenshake_requested.emit(5.0, 0.25)
	if health != null and health.damage(3.0, Vector2.ZERO):
		Events.boss_health_changed.emit(boss_id, health.current, health.max_health)


func _spawn_edict_hazard(kind: StringName) -> void:
	if kind == &"grapple":
		# A broad carpet quake leaves the high gold hooks as the clean escape.
		var section_w := arena_rect.size.x / 3.0
		for i in 3:
			_spawn_royal_hazard(
					Vector2(arena_rect.position.x + section_w * (i + 0.5), arena_rect.end.y - 13.0),
					Vector2.ZERO, Vector2(section_w - 12.0, 26.0), 0.9,
					Color(0.96, 0.58, 0.16), 0.45)
		Events.screenshake_requested.emit(5.0, 0.3)
		return
	# A thick beam clips a standing chair's upper hurtbox but leaves a folded
	# chair safely below it. Jumping rises farther into the danger band.
	var player := player_node()
	var from_left := player == null or player.global_position.x > arena_rect.get_center().x
	var start_x := arena_rect.position.x - 120.0 if from_left else arena_rect.end.x + 120.0
	var speed := 760.0 if from_left else -760.0
	_spawn_royal_hazard(Vector2(start_x, arena_rect.end.y - 82.0),
			Vector2(speed, 0), Vector2(210.0, 80.0), 2.2, Color(0.72, 0.24, 0.82))


func _spawn_royal_hazard(at: Vector2, vel: Vector2, hazard_size: Vector2,
		life: float, hazard_color: Color, warmup: float = 0.25) -> void:
	if not active or defeated:
		return
	var hazard := ROYAL_HAZARD_SCRIPT.new()
	hazard.velocity = vel
	hazard.size = hazard_size
	hazard.lifetime = life
	hazard.color = hazard_color
	hazard.warmup = warmup
	get_parent().add_child(hazard)
	hazard.global_position = at
	Events.sfx_requested.emit(&"telegraph")


func _build_edict_ui() -> void:
	_edict_layer = CanvasLayer.new()
	_edict_layer.layer = 8
	add_child(_edict_layer)
	_edict_panel = PanelContainer.new()
	_edict_panel.anchor_left = 0.5
	_edict_panel.anchor_right = 0.5
	_edict_panel.offset_left = -390.0
	_edict_panel.offset_top = 162.0
	_edict_panel.offset_right = 390.0
	_edict_panel.offset_bottom = 262.0
	_edict_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.018, 0.12, 0.94)
	panel_style.border_color = Color(0.96, 0.76, 0.22, 0.9)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	_edict_panel.add_theme_stylebox_override("panel", panel_style)
	_edict_layer.add_child(_edict_panel)
	_edict_label = Label.new()
	_edict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edict_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_edict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edict_label.add_theme_font_size_override("font_size", 20)
	_edict_label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.07))
	_edict_label.add_theme_constant_override("outline_size", 6)
	_edict_panel.add_child(_edict_label)
	_edict_panel.visible = false


func _show_edict(title: String, hint: String, color: Color) -> void:
	if _edict_panel == null or _edict_label == null:
		return
	_edict_label.text = "%s\n%s" % [title, hint]
	_edict_label.add_theme_color_override("font_color", color)
	_edict_panel.visible = true


# -- royal attack patterns --------------------------------------------------

func _royal_smash() -> void:
	await telegraph(0.55)
	hop(Vector2(dir_to_player() * 280.0, -570.0))
	await wait(0.38)
	velocity.y = 1050.0
	await _wait_for_floor(0.65)
	velocity.x = 0.0
	# Fast, low arcs skim the carpet in both directions and invite a hop.
	var wave_y := global_position.y - 18.0
	spawn_projectile(global_position + Vector2(-body_half_width - 12.0, -18.0),
			Vector2(-840.0, -190.0), Color(0.96, 0.72, 0.2), 11.0)
	spawn_projectile(Vector2(global_position.x + body_half_width + 12.0, wave_y),
			Vector2(840.0, -190.0), Color(0.96, 0.72, 0.2), 11.0)
	Events.screenshake_requested.emit(6.0, 0.3)
	await wait(0.8)


func _summon_court() -> void:
	await telegraph(0.65)
	if _arena_footstool_count() < 3:
		var court_x := [arena_rect.position.x + 150.0, arena_rect.end.x - 150.0]
		for x: float in court_x:
			var add := FOOTSTOOL_SCRIPT.new()
			add.position = Vector2(x, arena_rect.end.y - 1.0)
			add.skin_color = Color(0.48, 0.19, 0.62)
			get_parent().add_child(add)
			# Court etiquette: bow before re-hitting the same guest.
			for child in add.get_children():
				if child is Hitbox and (child as Hitbox).continuous:
					(child as Hitbox).rehit_interval = 2.0
			await wait(0.16)
	await wait(1.0)


func _cushion_volley() -> void:
	await telegraph(0.6)
	var origin := global_position + Vector2(0, -body_height + 28.0)
	var flight_time := 1.05
	for i in 5:
		var target_x := lerpf(arena_rect.position.x + 135.0,
				arena_rect.end.x - 135.0, float(i) / 4.0)
		var target := Vector2(target_x, arena_rect.end.y - 14.0)
		var delta_to_target := target - origin
		var launch := Vector2(delta_to_target.x / flight_time,
				(delta_to_target.y - 0.5 * Projectile.GRAVITY * flight_time * flight_time) / flight_time)
		spawn_projectile(origin, launch, Color(0.63, 0.25, 0.78), 13.0)
		await wait(0.13)
	await wait(0.85)


func _throne_charge() -> void:
	await telegraph(0.65)
	var left_x := arena_rect.position.x + body_half_width + 110.0
	var right_x := arena_rect.end.x - body_half_width - 110.0
	var start_x := left_x if absf(global_position.x - left_x) < absf(global_position.x - right_x) else right_x
	await move_to_x(start_x, 650.0, 2.5)
	var squash := create_tween()
	squash.tween_property(self, "scale:y", 0.56, 0.12)
	await wait(0.16)
	# Two true wall-to-wall passes, low enough to read as a charging throne.
	for pass_index in 2:
		var target_x := right_x if (pass_index == 0 and start_x == left_x) \
				or (pass_index == 1 and start_x == right_x) else left_x
		await move_to_x(target_x, 1050.0, 1.8)
		Events.screenshake_requested.emit(4.0, 0.18)
		await wait(0.25)
	var rise := create_tween()
	rise.tween_property(self, "scale:y", 1.0, 0.14)
	await wait(0.9)


func _wait_for_floor(timeout: float) -> void:
	var left := timeout
	while left > 0.0 and active and not defeated and not is_on_floor():
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _arena_footstool_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.get_script() != FOOTSTOOL_SCRIPT:
			continue
		# Enemy origins are at their feet, exactly on arena_rect.end.y.
		if arena_rect.has_point(enemy.global_position + Vector2(0, -1.0)):
			count += 1
	return count


func _on_died() -> void:
	_clear_edict()
	super._on_died()
	# BossBase fades and frees this node before two seconds elapse. Connect the
	# SceneTreeTimer to the persistent event bus so the awaited finale cannot be
	# cancelled along with the King's coroutine state.
	var victory_timer := get_tree().create_timer(2.0, false, true)
	victory_timer.timeout.connect(Events.game_won.emit, CONNECT_ONE_SHOT)
	await victory_timer.timeout


# -- placeholder portrait --------------------------------------------------

func _draw() -> void:
	var violet := Color(0.39, 0.105, 0.55)
	var royal_dark := Color(0.16, 0.035, 0.25)
	var gold := Color(0.98, 0.75, 0.18)
	var gold_dark := Color(0.55, 0.32, 0.06)
	var outline := Color(0.075, 0.018, 0.11)
	var flash := _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0
	if flash:
		violet = Color.WHITE
		royal_dark = Color(0.88, 0.88, 0.92)
	var w := body_half_width * 2.0
	var h := body_height

	# Cape and towering button-tufted throne back.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.72, -8), Vector2(-w * 0.61, -h * 0.82),
		Vector2(0, -h - 10), Vector2(w * 0.61, -h * 0.82), Vector2(w * 0.72, -8),
	]), royal_dark)
	draw_rect(Rect2(-w * 0.43, -h, w * 0.86, h - 10.0), violet)
	draw_rect(Rect2(-w * 0.43, -h, w * 0.86, h - 10.0), outline, false, 4.0)
	draw_line(Vector2(-w * 0.34, -h + 10), Vector2(-w * 0.34, -22), gold_dark, 5.0)
	draw_line(Vector2(w * 0.34, -h + 10), Vector2(w * 0.34, -22), gold_dark, 5.0)

	# Monumental arms and squat gilded feet.
	draw_rect(Rect2(-w * 0.62, -h * 0.58, 31, h * 0.5), royal_dark)
	draw_rect(Rect2(w * 0.62 - 31, -h * 0.58, 31, h * 0.5), royal_dark)
	draw_rect(Rect2(-w * 0.62, -h * 0.58, 31, h * 0.5), gold, false, 4.0)
	draw_rect(Rect2(w * 0.62 - 31, -h * 0.58, 31, h * 0.5), gold, false, 4.0)
	draw_rect(Rect2(-w * 0.48, -18, 33, 18), gold_dark)
	draw_rect(Rect2(w * 0.48 - 33, -18, 33, 18), gold_dark)

	# A crown far too grand for a piece of furniture.
	var crown := PackedVector2Array([
		Vector2(-48, -h + 3), Vector2(-58, -h - 40), Vector2(-27, -h - 20),
		Vector2(0, -h - 54), Vector2(27, -h - 20), Vector2(58, -h - 40),
		Vector2(48, -h + 3),
	])
	draw_colored_polygon(crown, gold)
	draw_polyline(crown + PackedVector2Array([crown[0]]), outline, 4.0)
	for jewel_x in [-29.0, 0.0, 29.0]:
		draw_circle(Vector2(jewel_x, -h - 8), 6.0, Color(0.72, 0.13, 0.25))

	# Tassels bounce at either side of His Cushioned Majesty.
	for side in [-1.0, 1.0]:
		var tassel_x: float = float(side) * (w * 0.61)
		draw_line(Vector2(tassel_x, -h * 0.72), Vector2(tassel_x, -h * 0.38), gold, 4.0)
		draw_circle(Vector2(tassel_x, -h * 0.34), 9.0, gold)
		draw_line(Vector2(tassel_x - 7, -h * 0.29), Vector2(tassel_x - 9, -h * 0.2), gold, 3.0)
		draw_line(Vector2(tassel_x + 7, -h * 0.29), Vector2(tassel_x + 9, -h * 0.2), gold, 3.0)

	# Deeply unimpressed eyes, brows, and royal button tufts.
	var look := dir_to_player() * 3.0
	for eye_x in [-23.0, 23.0]:
		draw_circle(Vector2(eye_x, -h + 54), 11.0, Color(1.0, 0.94, 0.72))
		draw_circle(Vector2(eye_x + look, -h + 56), 4.5, outline)
	draw_line(Vector2(-38, -h + 37), Vector2(-12, -h + 45), outline, 6.0)
	draw_line(Vector2(12, -h + 45), Vector2(38, -h + 37), outline, 6.0)
	draw_line(Vector2(-18, -h + 82), Vector2(0, -h + 76), gold_dark, 3.0)
	draw_line(Vector2(0, -h + 76), Vector2(18, -h + 82), gold_dark, 3.0)
	for tuft_y in [-72.0, -42.0]:
		for tuft_x in [-25.0, 0.0, 25.0]:
			draw_circle(Vector2(tuft_x, tuft_y), 4.0, gold_dark)
