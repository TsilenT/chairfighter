extends BossBase
## The Steel Folder — Storage boss, unlocks Folding Chair + High Chair.
## A hostile folding chair that weaponizes its suspiciously compact profile.

var _flat_pose := false
var _ricochet_pose := false


func _ready() -> void:
	boss_id = &"folder"
	display_name = "The Steel Folder"
	max_health = 40.0  # tuned down at integration: fast mover, casual difficulty
	unlock_form_ids = [&"folding", &"highchair"]
	body_half_width = 50.0
	body_height = 130.0
	contact_damage = 1.0
	super._ready()


func _patterns() -> Array[Callable]:
	return [_snap_slam, _low_slide, _ricochet]


func _on_phase_two() -> void:
	# The existing patterns read phase at launch: slides gain a return pass and
	# ricochets gain both speed and an extra wall bounce.
	Events.screenshake_requested.emit(4.0, 0.2)
	queue_redraw()


# ── patterns ──

func _snap_slam() -> void:
	await telegraph(0.5)
	if not active or defeated:
		return
	var p := player_node()
	var target_x := global_position.x
	if p != null:
		target_x = clampf(p.global_position.x,
				arena_rect.position.x + body_half_width + 36.0,
				arena_rect.end.x - body_half_width - 36.0)
	var dx := target_x - global_position.x
	velocity = Vector2(clampf(dx / 0.5, -580.0, 580.0), -820.0)
	await wait(0.32)
	if not active or defeated:
		return
	# Snap shut at the apex, then drop much faster than gravity alone.
	velocity.x = 0.0
	velocity.y = 1100.0
	var landed := await _wait_for_landing(1.0)
	if not landed or not active or defeated:
		return
	velocity = Vector2.ZERO
	Events.screenshake_requested.emit(6.0, 0.25)
	# Low, skimming metal shards give the player a readable jump check.
	spawn_projectile(global_position + Vector2(-54.0, -22.0),
			Vector2(-500.0, -170.0), Color(0.88, 0.9, 0.94), 9.0)
	spawn_projectile(global_position + Vector2(54.0, -22.0),
			Vector2(500.0, -170.0), Color(0.88, 0.9, 0.94), 9.0)
	await wait(0.65)


func _low_slide() -> void:
	await telegraph(0.5)
	if not active or defeated:
		return
	_set_flat_pose(true)
	Events.sfx_requested.emit(&"dash")
	var left_edge := arena_rect.position.x + body_half_width + 26.0
	var right_edge := arena_rect.end.x - body_half_width - 26.0
	var arena_center := arena_rect.position.x + arena_rect.size.x * 0.5
	var slide_dir := dir_to_player()
	if absf(global_position.x - (player_node().global_position.x if player_node() != null else arena_center)) < 30.0:
		slide_dir = -1.0 if global_position.x > arena_center else 1.0
	var target := right_edge if slide_dir > 0.0 else left_edge
	var passes := 2 if phase >= 2 else 1
	for pass_index in passes:
		await move_to_x(target, 500.0, 3.0)
		if not active or defeated:
			break
		velocity.x = 0.0
		await wait(0.22)
		if pass_index + 1 < passes:
			target = left_edge if target > arena_center else right_edge
	_set_flat_pose(false)
	velocity.x = 0.0
	if active and not defeated:
		await wait(0.7)


func _ricochet() -> void:
	await telegraph(0.55)
	if not active or defeated:
		return
	_ricochet_pose = true
	use_gravity = false
	queue_redraw()
	var token := _run_token
	var speed := 660.0 if phase >= 2 else 480.0
	var vertical_speed := 450.0 if phase >= 2 else 360.0
	var bounce_goal := 3 if phase >= 2 else 2
	var left_edge := arena_rect.position.x + body_half_width + 24.0
	var right_edge := arena_rect.end.x - body_half_width - 24.0
	var top_edge := arena_rect.position.y + body_height + 42.0
	var bottom_edge := arena_rect.end.y
	var x_dir := dir_to_player()
	if x_dir == 0.0:
		x_dir = -1.0
	var y_dir := -1.0
	var bounces := 0
	var time_left := 8.0
	velocity = Vector2(x_dir * speed, y_dir * vertical_speed)
	while bounces < bounce_goal and time_left > 0.0 \
			and token == _run_token and active and not defeated:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		time_left -= delta
		# Keep the motion deterministic even when move_and_slide touches an
		# authored arena wall a few pixels inside the camera-lock rectangle.
		if x_dir < 0.0 and (global_position.x <= left_edge + 12.0 or is_on_wall()):
			if global_position.x <= left_edge + 12.0:
				global_position.x = left_edge
			x_dir = 1.0
			bounces += 1
			Events.screenshake_requested.emit(2.5, 0.12)
		elif x_dir > 0.0 and (global_position.x >= right_edge - 12.0 or is_on_wall()):
			if global_position.x >= right_edge - 12.0:
				global_position.x = right_edge
			x_dir = -1.0
			bounces += 1
			Events.screenshake_requested.emit(2.5, 0.12)
		if y_dir < 0.0 and global_position.y <= top_edge:
			global_position.y = top_edge
			y_dir = 1.0
		elif y_dir > 0.0 and global_position.y >= bottom_edge - 2.0:
			global_position.y = bottom_edge - 2.0
			y_dir = -1.0
		velocity = Vector2(x_dir * speed, y_dir * vertical_speed)
	_ricochet_pose = false
	use_gravity = true
	queue_redraw()
	if token != _run_token or not active or defeated:
		velocity = Vector2.ZERO
		return
	velocity = Vector2(0.0, 520.0)
	await _wait_for_landing(1.5)
	velocity = Vector2.ZERO
	await wait(0.7)


func _set_flat_pose(value: bool) -> void:
	_flat_pose = value
	var pose_height := 30.0 if value else body_height
	# Match the gameplay silhouette to the drawing so a jump really clears the
	# slide. Restore the configured 100x130 body as soon as the pass ends.
	for child in get_children():
		if child is CollisionShape2D:
			var body_shape := (child as CollisionShape2D).shape as RectangleShape2D
			if body_shape != null:
				body_shape.size = Vector2(body_half_width * 2.0, pose_height)
				(child as CollisionShape2D).position.y = -pose_height / 2.0
		elif child is Hurtbox or child is Hitbox:
			for shape_node in child.get_children():
				if not (shape_node is CollisionShape2D):
					continue
				var attack_shape := (shape_node as CollisionShape2D).shape as RectangleShape2D
				if attack_shape == null:
					continue
				if child is Hitbox:
					attack_shape.size = Vector2(body_half_width * 2.0 - 8.0,
							maxf(pose_height - 8.0, 18.0))
				else:
					attack_shape.size = Vector2(body_half_width * 2.0, pose_height)
				(shape_node as CollisionShape2D).position.y = -pose_height / 2.0
	queue_redraw()


func _wait_for_landing(timeout: float) -> bool:
	var token := _run_token
	var left := timeout
	# Always give the launch/drop one physics tick before testing is_on_floor.
	await get_tree().physics_frame
	while left > 0.0 and token == _run_token and active and not defeated:
		if is_on_floor():
			return true
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	return false


# ── placeholder visual (Phase 4 re-skins) ──

func _draw() -> void:
	var silver := Color(0.68, 0.72, 0.76)
	var bright := Color(0.9, 0.93, 0.96)
	var shadow := Color(0.28, 0.32, 0.36)
	var outline := Color(0.08, 0.1, 0.12)
	var warning := Color(0.96, 0.78, 0.16)
	var flash := _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0
	if flash:
		silver = Color.WHITE
		bright = Color.WHITE
		shadow = Color(0.82, 0.86, 0.9)
	if _flat_pose:
		# Folded nearly flush with the floor: a glinting metal jump hazard.
		draw_rect(Rect2(-72.0, -27.0, 144.0, 22.0), shadow)
		draw_rect(Rect2(-68.0, -31.0, 136.0, 20.0), silver)
		draw_rect(Rect2(-68.0, -31.0, 136.0, 20.0), outline, false, 3.0)
		draw_line(Vector2(-55.0, -24.0), Vector2(50.0, -24.0), bright, 3.0)
		draw_line(Vector2(-58.0, -8.0), Vector2(58.0, -29.0), shadow, 5.0)
		# Narrow eyes remain visible even when the chair is fully folded.
		draw_line(Vector2(-23.0, -20.0), Vector2(-7.0, -17.0), warning, 4.0)
		draw_line(Vector2(7.0, -17.0), Vector2(23.0, -20.0), warning, 4.0)
		draw_circle(Vector2(58.0, -23.0), 4.0, bright)
		return

	var h := body_height
	var w := body_half_width * 2.0
	# Backrest and punched-steel inset.
	draw_rect(Rect2(-w * 0.4, -h, w * 0.8, 70.0), shadow)
	draw_rect(Rect2(-w * 0.36, -h + 4.0, w * 0.72, 62.0), silver)
	draw_rect(Rect2(-w * 0.4, -h, w * 0.8, 70.0), outline, false, 4.0)
	draw_line(Vector2(-27.0, -h + 15.0), Vector2(25.0, -h + 6.0), bright, 3.0)
	# Seat and hinge barrels.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.52, -62.0), Vector2(w * 0.52, -62.0),
		Vector2(w * 0.43, -39.0), Vector2(-w * 0.43, -39.0),
	]), silver)
	draw_polyline(PackedVector2Array([
		Vector2(-w * 0.52, -62.0), Vector2(w * 0.52, -62.0),
		Vector2(w * 0.43, -39.0), Vector2(-w * 0.43, -39.0),
		Vector2(-w * 0.52, -62.0),
	]), outline, 4.0)
	draw_circle(Vector2(-w * 0.42, -49.0), 7.0, warning)
	draw_circle(Vector2(w * 0.42, -49.0), 7.0, warning)
	draw_circle(Vector2(-w * 0.42, -49.0), 7.0, outline, false, 2.5)
	draw_circle(Vector2(w * 0.42, -49.0), 7.0, outline, false, 2.5)
	# Crossed folding legs make the silhouette unmistakable.
	draw_line(Vector2(-36.0, -45.0), Vector2(34.0, -2.0), shadow, 10.0)
	draw_line(Vector2(36.0, -45.0), Vector2(-34.0, -2.0), silver, 10.0)
	draw_line(Vector2(-36.0, -45.0), Vector2(34.0, -2.0), outline, 2.5)
	draw_line(Vector2(36.0, -45.0), Vector2(-34.0, -2.0), outline, 2.5)
	draw_line(Vector2(-43.0, -2.0), Vector2(-24.0, -2.0), bright, 5.0)
	draw_line(Vector2(24.0, -2.0), Vector2(43.0, -2.0), bright, 5.0)
	# Narrow, suspicious eyes under a severe metal brow.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-25.0, -h + 28.0), Vector2(-5.0, -h + 32.0),
		Vector2(-7.0, -h + 39.0), Vector2(-24.0, -h + 36.0),
	]), warning)
	draw_colored_polygon(PackedVector2Array([
		Vector2(25.0, -h + 28.0), Vector2(5.0, -h + 32.0),
		Vector2(7.0, -h + 39.0), Vector2(24.0, -h + 36.0),
	]), warning)
	draw_line(Vector2(-27.0, -h + 25.0), Vector2(-4.0, -h + 31.0), outline, 4.0)
	draw_line(Vector2(27.0, -h + 25.0), Vector2(4.0, -h + 31.0), outline, 4.0)
	if _ricochet_pose:
		draw_arc(Vector2.ZERO, 62.0, -2.7, -0.45, 18, bright, 4.0)
		draw_line(Vector2(-62.0, -82.0), Vector2(-82.0, -94.0), warning, 4.0)
		draw_line(Vector2(62.0, -62.0), Vector2(82.0, -74.0), warning, 4.0)
