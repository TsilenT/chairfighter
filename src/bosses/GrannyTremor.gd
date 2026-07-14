extends BossBase
## Granny Tremor — Parlor boss, unlocks the Rocking Chair.
##
## Her floor passes teach the launch's hop timing; her stomp previews the
## ground-shaking landing that the player earns by defeating her.

var _rocking := false
var _charging := false
var _stomping := false
var _rock_time := 0.0
var _rock_angle := 0.0
var _charge_dir := 1.0
var _contact_hitbox: Hitbox


func _ready() -> void:
	boss_id = &"granny"
	display_name = "Granny Tremor"
	max_health = 55.0
	unlock_form_id = &"rocking"
	body_half_width = 55.0
	body_height = 130.0
	contact_damage = 1.0
	super._ready()
	# Her lap is a safe punish window. Contact turns dangerous only while an
	# attack is moving, which keeps the driver's close-range trades fair.
	for child in get_children():
		if child is Hitbox and (child as Hitbox).continuous:
			_contact_hitbox = child as Hitbox
			_contact_hitbox.rehit_interval = 2.0
			break
	_set_contact_active(false)


func _patterns() -> Array[Callable]:
	return [_rocking_charge, _knit_barrage, _tremor_stomp]


func _on_phase_two() -> void:
	# A shudder announces the faster, three-pass rhythm without injecting a
	# hop into whichever attack coroutine crossed the health threshold.
	_rock_time = 0.0
	Events.screenshake_requested.emit(4.0, 0.25)
	queue_redraw()


func _on_player_died() -> void:
	_reset_attack_pose()
	super._on_player_died()


func _physics_process(delta: float) -> void:
	if _rocking:
		_rock_time += delta
		var intensity := minf(_rock_time / 0.9, 1.0)
		var frequency := lerpf(7.0, 24.0, intensity)
		_rock_angle = sin(_rock_time * frequency) * lerpf(0.035, 0.17, intensity)
	else:
		_rock_angle = move_toward(_rock_angle, 0.0, delta * 1.8)
	super._physics_process(delta)


func _set_contact_active(enabled: bool) -> void:
	if _contact_hitbox != null and is_instance_valid(_contact_hitbox):
		_contact_hitbox.set_deferred("monitoring", enabled)


func _reset_attack_pose() -> void:
	_rocking = false
	_charging = false
	_stomping = false
	_rock_time = 0.0
	_rock_angle = 0.0
	use_gravity = true
	_set_contact_active(false)
	queue_redraw()


# -- patterns ---------------------------------------------------------------

func _rocking_charge() -> void:
	await telegraph(0.55)
	if not active or defeated:
		return

	# Rock in place until the tempo audibly/visually winds up.
	velocity.x = 0.0
	_rock_time = 0.0
	_rocking = true
	await wait(0.72 if phase >= 2 else 0.9)
	_rocking = false
	_rock_angle = 0.0
	if not active or defeated:
		_reset_attack_pose()
		return

	var pass_count := 3 if phase >= 2 else 2
	var speed := 640.0 if phase >= 2 else 520.0
	var left_x := arena_rect.position.x + body_half_width + 72.0
	var right_x := arena_rect.end.x - body_half_width - 72.0
	var arena_mid := arena_rect.position.x + arena_rect.size.x * 0.5

	for pass_index in pass_count:
		var target_x := right_x if global_position.x < arena_mid else left_x
		_charge_dir = signf(target_x - global_position.x)
		if is_zero_approx(_charge_dir):
			_charge_dir = dir_to_player()
		_charging = true
		_set_contact_active(true)
		await move_to_x(target_x, speed, 2.5)
		velocity.x = 0.0
		_charging = false
		_set_contact_active(false)
		if not active or defeated:
			_reset_attack_pose()
			return
		if pass_index + 1 < pass_count:
			# The runner squeak is the beat before the return sweep.
			await wait(0.28)
	await wait(0.72)


func _knit_barrage() -> void:
	await telegraph(0.5)
	if not active or defeated:
		return
	var count := 6 if phase >= 2 else 4
	var dusty_rose := Color(0.74, 0.34, 0.46)
	var origin := global_position + Vector2(0, -body_height + 22.0)
	var p := player_node()
	if p == null:
		return
	var center_x := p.global_position.x
	var flight_time := 0.92
	for i in count:
		if not active or defeated:
			return
		var spread := (float(i) - (float(count) - 1.0) * 0.5) * 78.0
		var target_x := clampf(center_x + spread,
				arena_rect.position.x + 86.0, arena_rect.end.x - 86.0)
		var target := Vector2(target_x, arena_rect.end.y - 12.0)
		var delta_to_target := target - origin
		var yarn_velocity := Vector2(delta_to_target.x / flight_time,
				(delta_to_target.y - 0.5 * Projectile.GRAVITY
				* flight_time * flight_time) / flight_time)
		spawn_projectile(origin, yarn_velocity, dusty_rose, 10.0)
		await wait(0.16)
	# Granny counts her stitches, leaving a clear melee opening.
	await wait(0.82)


func _tremor_stomp() -> void:
	await telegraph(0.55)
	if not active or defeated:
		return
	_stomping = true
	_set_contact_active(true)
	hop(Vector2(dir_to_player() * 180.0, -660.0))
	await wait(0.36)
	if not active or defeated:
		_reset_attack_pose()
		return
	velocity.x *= 0.35
	velocity.y = 1120.0
	var landed := await _wait_for_landing(1.2)
	if not landed or not active or defeated:
		_reset_attack_pose()
		return
	velocity = Vector2.ZERO
	Events.screenshake_requested.emit(6.0, 0.28)
	var wave_origin := global_position + Vector2(0, -18.0)
	var wave_color := Color(0.82, 0.57, 0.36)
	spawn_projectile(wave_origin + Vector2(-20.0, 0), Vector2(-660.0, -175.0),
			wave_color, 9.0)
	spawn_projectile(wave_origin + Vector2(20.0, 0), Vector2(660.0, -175.0),
			wave_color, 9.0)
	_stomping = false
	_set_contact_active(false)
	await wait(0.78)


func _wait_for_landing(timeout: float) -> bool:
	var token := _run_token
	var left := timeout
	# The launch begins while the previous frame still reports floor contact.
	await get_tree().physics_frame
	while left > 0.0 and token == _run_token and active and not defeated:
		if is_on_floor():
			return true
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	return false


# -- placeholder visual ----------------------------------------------------

func _draw() -> void:
	var wood := Color(0.29, 0.15, 0.105)
	var wood_light := Color(0.48, 0.27, 0.18)
	var shawl := Color(0.58, 0.29, 0.4) if phase == 1 else Color(0.76, 0.36, 0.48)
	var shawl_light := Color(0.78, 0.48, 0.56)
	var brass := Color(0.83, 0.64, 0.28)
	var outline := Color(0.11, 0.055, 0.045)
	var flash := _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0
	if flash:
		wood = Color.WHITE
		wood_light = Color.WHITE
		shawl = Color.WHITE
		shawl_light = Color.WHITE

	# Rotate the drawing around the feet without rotating the physics body.
	draw_set_transform(Vector2.ZERO, _rock_angle, Vector2.ONE)
	# Broad curved runner and chair legs.
	draw_polyline(PackedVector2Array([
		Vector2(-61, -5), Vector2(-42, -1), Vector2(0, 2),
		Vector2(42, -1), Vector2(61, -5),
	]), outline, 9.0)
	draw_polyline(PackedVector2Array([
		Vector2(-58, -7), Vector2(-38, -4), Vector2(0, -2),
		Vector2(38, -4), Vector2(58, -7),
	]), wood_light, 4.0)
	draw_line(Vector2(-32, -46), Vector2(-43, -7), outline, 10.0)
	draw_line(Vector2(32, -46), Vector2(43, -7), outline, 10.0)
	draw_line(Vector2(-32, -46), Vector2(-43, -7), wood, 5.0)
	draw_line(Vector2(32, -46), Vector2(43, -7), wood, 5.0)

	# Rocking-chair back, seat, posts, and curled arms.
	draw_rect(Rect2(-42, -126, 84, 82), outline)
	draw_rect(Rect2(-37, -121, 74, 72), wood)
	for slat_x in [-25.0, 0.0, 25.0]:
		draw_line(Vector2(slat_x, -116), Vector2(slat_x, -56), wood_light, 5.0)
	draw_rect(Rect2(-54, -58, 108, 24), outline)
	draw_rect(Rect2(-49, -54, 98, 16), wood_light)
	draw_line(Vector2(-48, -62), Vector2(-61, -41), outline, 8.0)
	draw_line(Vector2(48, -62), Vector2(61, -41), outline, 8.0)
	draw_circle(Vector2(-61, -40), 7.0, brass)
	draw_circle(Vector2(61, -40), 7.0, brass)

	# Shawl and unmistakable granny spectacles.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -119), Vector2(0, -128), Vector2(40, -119),
		Vector2(51, -75), Vector2(20, -88), Vector2(0, -62),
		Vector2(-20, -88), Vector2(-51, -75),
	]), shawl)
	draw_polyline(PackedVector2Array([
		Vector2(-40, -119), Vector2(0, -128), Vector2(40, -119),
		Vector2(51, -75),
	]), shawl_light, 4.0)
	var look := dir_to_player() * 2.0
	for eye_x in [-17.0, 17.0]:
		draw_circle(Vector2(eye_x, -101), 11.0, Color(0.93, 0.86, 0.77))
		draw_arc(Vector2(eye_x, -101), 12.0, 0, TAU, 20, brass, 3.0)
		draw_circle(Vector2(eye_x + look, -100), 3.3, outline)
	draw_line(Vector2(-5, -101), Vector2(5, -101), brass, 3.0)
	draw_line(Vector2(-13, -82), Vector2(0, -78), outline, 2.5)
	draw_line(Vector2(0, -78), Vector2(13, -82), outline, 2.5)

	# Yarn basket, complete with one doomed loose strand.
	draw_colored_polygon(PackedVector2Array([
		Vector2(53, -28), Vector2(89, -28), Vector2(84, -3), Vector2(58, -3),
	]), wood_light)
	draw_polyline(PackedVector2Array([
		Vector2(53, -28), Vector2(89, -28), Vector2(84, -3),
		Vector2(58, -3), Vector2(53, -28),
	]), outline, 3.0)
	draw_circle(Vector2(64, -30), 11.0, shawl)
	draw_circle(Vector2(78, -31), 10.0, shawl_light)
	draw_arc(Vector2(87, -12), 27.0, 0.3, 1.7, 14, shawl, 2.5)

	if _charging:
		for i in 3:
			var trail := -_charge_dir
			var y := -100.0 + float(i) * 28.0
			draw_line(Vector2(trail * 68.0, y), Vector2(trail * (96.0 + i * 8.0), y),
					brass, 3.0)
	if _stomping:
		draw_arc(Vector2(0, -4), 70.0, PI + 0.15, TAU - 0.15, 22,
				Color(brass.r, brass.g, brass.b, 0.6), 4.0)
