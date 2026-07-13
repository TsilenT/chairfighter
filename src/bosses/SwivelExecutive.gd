extends "res://src/bosses/BossBase.gd"
## The Swivel Executive — Office Complex boss, unlocks the Office Chair.
##
## Patterns: an arena-wide rolling charge, a shower of overdue paperwork,
## and a swivel-assisted hop that ends in a pair of low shockwaves. Phase 2
## turns every roll into a two-pass charge.

var _rolling := false
var _slamming := false
var _charge_dir := 1.0
var _wheel_spin := 0.0
var _contact_hitbox: Hitbox


func _ready() -> void:
	boss_id = &"swivel"
	display_name = "The Swivel Executive"
	max_health = 50.0
	unlock_form_id = &"office"
	body_half_width = 60.0
	body_height = 110.0
	contact_damage = 1.0
	super._ready()
	# Proximity is the punish window; body contact only hurts while the chair
	# is physically charging or slamming.
	for child in get_children():
		if child is Hitbox and (child as Hitbox).continuous:
			_contact_hitbox = child as Hitbox
			break
	_set_contact_active(false)


func _patterns() -> Array[Callable]:
	var list: Array[Callable] = [_roll_charge, _paper_storm, _swivel_slam]
	return list


func _on_phase_two() -> void:
	# An indignant little bounce announces that future charges come in pairs.
	hop(Vector2(0, -440.0))


func _on_player_died() -> void:
	_set_contact_active(false)
	super._on_player_died()


func _physics_process(delta: float) -> void:
	var spin_rate := 17.0 if _rolling else (8.0 if phase >= 2 else 4.5)
	_wheel_spin = fmod(_wheel_spin + delta * spin_rate, TAU)
	super._physics_process(delta)


func _set_contact_active(enabled: bool) -> void:
	if _contact_hitbox != null and is_instance_valid(_contact_hitbox):
		_contact_hitbox.set_deferred("monitoring", enabled)


# -- patterns ---------------------------------------------------------------

func _roll_charge() -> void:
	await telegraph(0.5)
	var charge_count := 2 if phase >= 2 else 1
	var speed := 800.0 if phase >= 2 else 650.0
	var left_edge := arena_rect.position.x + body_half_width + 28.0
	var right_edge := arena_rect.end.x - body_half_width - 28.0
	var arena_mid := arena_rect.position.x + arena_rect.size.x * 0.5

	for pass_index in charge_count:
		# Pick the far edge so the move always crosses the arena, even after
		# the player has chased the boss into a corner.
		var target_x := right_edge if global_position.x < arena_mid else left_edge
		_charge_dir = signf(target_x - global_position.x)
		if is_zero_approx(_charge_dir):
			_charge_dir = dir_to_player()
		_rolling = true
		_set_contact_active(true)
		await move_to_x(target_x, speed, 2.4)
		velocity.x = 0.0
		_rolling = false
		_set_contact_active(false)
		if pass_index + 1 < charge_count:
			# A short brake squeal is the tell for the immediate return pass.
			await wait(0.32)
	await wait(0.58)


func _paper_storm() -> void:
	await telegraph(0.5)
	var p := player_node()
	if p == null:
		return
	var count := 6 if phase >= 2 else 4
	var center_x := p.global_position.x
	var spawn_y := arena_rect.position.y + 72.0
	for i in count:
		var spread := (float(i) - (float(count) - 1.0) * 0.5) * 74.0
		var paper_x := clampf(center_x + spread,
				arena_rect.position.x + 44.0, arena_rect.end.x - 44.0)
		var drift := -60.0 if i % 2 == 0 else 60.0
		var paper_color := Color(0.94, 0.96, 0.97) if i % 2 == 0 \
				else Color(0.68, 0.73, 0.77)
		spawn_projectile(Vector2(paper_x, spawn_y), Vector2(drift, -50.0),
				paper_color, 7.0)
		await wait(0.14)
	# The Executive admires the filing job; this is a generous punish window.
	await wait(0.72)


func _swivel_slam() -> void:
	await telegraph(0.55)
	var p := player_node()
	var hop_x := dir_to_player() * 360.0
	if p != null:
		var dx := clampf(p.global_position.x - global_position.x, -310.0, 310.0)
		hop_x = clampf(dx * 1.35, -440.0, 440.0)
	_slamming = true
	_set_contact_active(true)
	hop(Vector2(hop_x, -710.0))
	await wait(0.34)
	velocity.x *= 0.45
	velocity.y = 1150.0

	var token := _run_token
	var landing_time := 0.9
	while token == _run_token and not defeated and landing_time > 0.0:
		await get_tree().physics_frame
		landing_time -= get_physics_process_delta_time()
		if is_on_floor():
			break
	if token != _run_token or defeated:
		_slamming = false
		_set_contact_active(false)
		return

	velocity.x = 0.0
	Events.screenshake_requested.emit(5.0, 0.24)
	var wave_origin := global_position + Vector2(0, -20.0)
	spawn_projectile(wave_origin + Vector2(-18.0, 0), Vector2(-720.0, -220.0),
			Color(0.26, 0.78, 0.75), 8.0)
	spawn_projectile(wave_origin + Vector2(18.0, 0), Vector2(720.0, -220.0),
			Color(0.26, 0.78, 0.75), 8.0)
	_slamming = false
	_set_contact_active(false)
	await wait(0.68)


# -- placeholder visual (Phase 4 re-skins) ---------------------------------

func _draw() -> void:
	var outline := Color(0.035, 0.045, 0.055)
	var charcoal := Color(0.13, 0.16, 0.18)
	var upholstery := Color(0.28, 0.33, 0.36)
	var steel := Color(0.43, 0.5, 0.53)
	var teal := Color(0.12, 0.72, 0.69) if phase == 1 else Color(0.18, 0.94, 0.88)
	var flash := _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0
	if flash:
		charcoal = Color.WHITE
		upholstery = Color.WHITE
		steel = Color.WHITE

	# Five-spoke wheel base. The flattened radial motion reads as swivelling
	# while keeping every caster above the feet-origin floor line.
	var hub := Vector2(0, -16)
	for i in 5:
		var angle := _wheel_spin + float(i) * TAU / 5.0
		var spoke := Vector2(cos(angle) * 43.0, sin(angle) * 9.0)
		var caster := hub + spoke
		draw_line(hub, caster, outline, 7.0)
		draw_line(hub, caster, steel, 3.0)
		draw_circle(caster, 6.0, outline)
		draw_circle(caster, 3.5, charcoal)
		var accent := Vector2(cos(angle * 2.0), sin(angle * 2.0)) * 3.0
		draw_line(caster - accent, caster + accent, teal, 1.5)
	draw_circle(hub, 9.0, outline)
	draw_circle(hub, 5.0, steel)

	# Gas-lift stem, seat, back, and broad executive armrests.
	draw_rect(Rect2(-7, -40, 14, 25), outline)
	draw_rect(Rect2(-3, -39, 6, 23), steel)
	draw_rect(Rect2(-55, -53, 110, 24), outline)
	draw_rect(Rect2(-50, -49, 100, 16), charcoal)
	draw_rect(Rect2(-50, -108, 100, 65), outline)
	draw_rect(Rect2(-45, -104, 90, 57), upholstery)
	draw_rect(Rect2(-60, -69, 17, 35), outline)
	draw_rect(Rect2(43, -69, 17, 35), outline)
	draw_rect(Rect2(-57, -65, 12, 27), charcoal)
	draw_rect(Rect2(45, -65, 12, 27), charcoal)

	# Smug, narrowed eyes track the employee currently under review.
	var look := dir_to_player() * 2.5
	var left_eye := PackedVector2Array([
		Vector2(-31, -87), Vector2(-8, -84), Vector2(-11, -75), Vector2(-32, -78),
	])
	var right_eye := PackedVector2Array([
		Vector2(8, -84), Vector2(31, -87), Vector2(32, -78), Vector2(11, -75),
	])
	draw_colored_polygon(left_eye, Color(0.9, 0.94, 0.94))
	draw_colored_polygon(right_eye, Color(0.9, 0.94, 0.94))
	draw_circle(Vector2(-19 + look, -81), 3.5, outline)
	draw_circle(Vector2(19 + look, -81), 3.5, outline)
	draw_line(Vector2(-33, -91), Vector2(-8, -87), outline, 3.5)
	draw_line(Vector2(8, -87), Vector2(33, -91), outline, 3.5)
	# One-sided smirk and a tie loud enough to count as management training.
	draw_arc(Vector2(9, -69), 13.0, 0.25, 1.75, 12, outline, 2.5)
	var tie_points := PackedVector2Array([
		Vector2(0, -67), Vector2(-8, -59), Vector2(-5, -44),
		Vector2(0, -35), Vector2(5, -44), Vector2(8, -59),
	])
	draw_colored_polygon(tie_points, teal)
	draw_polyline(PackedVector2Array([
		Vector2(0, -67), Vector2(-8, -59), Vector2(-5, -44), Vector2(0, -35),
		Vector2(5, -44), Vector2(8, -59), Vector2(0, -67),
	]), outline, 2.0)

	if _rolling:
		# Speed marks trail opposite the current charge direction.
		var trail := -_charge_dir
		for i in 3:
			var y := -91.0 + float(i) * 25.0
			var near_x := trail * (64.0 + float(i) * 3.0)
			var far_x := trail * (91.0 + float(i) * 8.0)
			draw_line(Vector2(near_x, y), Vector2(far_x, y), teal, 3.0)
	if _slamming:
		draw_arc(Vector2(0, -18), 58.0, 0.12, PI - 0.12, 20,
				Color(teal.r, teal.g, teal.b, 0.55), 3.0)
