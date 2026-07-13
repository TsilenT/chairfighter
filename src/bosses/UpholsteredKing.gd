extends BossBase
## The Upholstered King — final ruler of every seat in the realm.

const FOOTSTOOL_SCRIPT := preload("res://src/enemies/Footstool.gd")


func _ready() -> void:
	boss_id = &"king"
	display_name = "The Upholstered King"
	max_health = 90.0
	unlock_form_id = &""
	body_half_width = 75.0
	body_height = 170.0
	contact_damage = 1.0
	super._ready()
	# The King is enormous, so melee naturally overlaps him. Keep the contact
	# hit honest but infrequent enough for the simple demo fighter to trade.
	for child in get_children():
		if child is Hitbox and (child as Hitbox).continuous:
			(child as Hitbox).rehit_interval = 4.5


func _patterns() -> Array[Callable]:
	var list: Array[Callable] = [_royal_smash, _summon_court, _cushion_volley]
	if phase >= 2:
		list.append(_throne_charge)
	return list


func _on_phase_two() -> void:
	# A royal tantrum, conducted entirely through upholstery.
	hop(Vector2(0, -650.0))


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
