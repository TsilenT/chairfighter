extends "res://src/bosses/FloorGuardian.gd"
## A garden stool with a spring-loaded seat. It commits to its landing before
## launching so the player can abandon that spot and close in on recovery.

const LEAF := Color(0.42, 0.74, 0.36)
const SPORE := Color(0.87, 0.7, 0.96)
const LIME := Color(0.82, 0.91, 0.39)

var _compressed := false
var _airborne_attack := false


func _ready() -> void:
	boss_id = &"bouncer"
	display_name = "The Canopy Bouncer"
	max_health = 65.0
	body_half_width = 59.0
	body_height = 115.0
	super._ready()


func _patterns() -> Array[Callable]:
	return [_spring_stomp, _spore_arc, _root_wave]


func _clear_attack() -> void:
	_compressed = false
	_airborne_attack = false
	super._clear_attack()


func _spring_stomp() -> void:
	var token := _run_token
	var count := 2 if phase == 2 else 1
	for jump in count:
		var point := player_floor_point()
		point.x = move_toward(global_position.x, point.x, 320.0)
		_compressed = true
		await telegraph(0.67 if jump == 0 else 0.52, "Spring landing", PackedVector2Array([point]))
		if not is_attack_current(token):
			return
		_compressed = false
		_airborne_attack = true
		_set_contact_active(true)
		var power := 950.0
		var flight := 2.0 * power / GRAVITY
		hop(Vector2((point.x - global_position.x) / flight, -power))
		await wait(0.28)
		if not is_attack_current(token):
			return
		var landed := await wait_for_landing(1.08)
		if not is_attack_current(token):
			return
		velocity.x = 0.0
		_airborne_attack = false
		_set_contact_active(false)
		if landed:
			Events.screenshake_requested.emit(5.0, 0.18)
			add_hazard(global_position + Vector2(0, -21), Vector2(152, 32), Vector2.ZERO, LIME, 0.31)
	await recover(1.07)


func _spore_arc() -> void:
	var token := _run_token
	var target := player_floor_point()
	var nudge := 1.0 if target.x < arena_rect.get_center().x else -1.0
	var points := PackedVector2Array([target, floor_point(target.x + nudge * 146.0)])
	if phase == 2:
		points.append(floor_point(target.x + nudge * 292.0))
	await telegraph(0.72, "Spore arc", points)
	for point in points:
		if not is_attack_current(token):
			return
		lob_to(global_position + Vector2(0, -105), point + Vector2(0, -17), 0.94, SPORE, 13.0, &"yarn")
		await wait(0.18)
	await recover(0.9)


func _root_wave() -> void:
	var token := _run_token
	_compressed = true
	await telegraph(0.68, "Jump the roots")
	if not is_attack_current(token):
		return
	_compressed = false
	for direction in [-1.0, 1.0]:
		var start := global_position + Vector2(direction * 66.0, -18.0)
		add_hazard(start, Vector2(62, 29), Vector2(direction * 390.0, 0.0), LEAF, 1.75)
	await recover(0.88)


func _draw() -> void:
	var stem := hit_tint(Color(0.46, 0.37, 0.26))
	var green := hit_tint(LEAF.darkened(0.13) if phase == 1 else LEAF)
	var cap_y := -93.0
	if _compressed:
		cap_y += 22.0
	elif _airborne_attack:
		cap_y -= 7.0
	for side in [-1.0, 1.0]:
		var foot := Vector2(side * 50.0, -3.0)
		draw_line(Vector2(side * 31.0, -30.0), foot, INK, 12.0, true)
		draw_line(Vector2(side * 31.0, -30.0), foot, stem, 7.0, true)
	paint_plate(Rect2(-42, -31, 84, 12), stem)
	var coil := PackedVector2Array()
	for i in 9:
		coil.append(Vector2(-20.0 if i % 2 == 0 else 20.0, lerpf(-29.0, cap_y + 20.0, i / 8.0)))
	draw_polyline(coil, INK, 10.0, true)
	draw_polyline(coil, LIME, 5.0, true)
	paint_plate(Rect2(-55, cap_y - 15, 110, 41), green)
	paint_plate(Rect2(-48, cap_y + 17, 96, 14), green.darkened(0.29))
	paint_eyes(Vector2(0, cap_y + 6.0), 19.0, 7.5, dir_to_player())
	for side in [-1.0, 1.0]:
		var leaf := PackedVector2Array([Vector2(side * 37.0, cap_y - 15.0),
			Vector2(side * 54.0, cap_y - 33.0), Vector2(side * 55.0, cap_y - 19.0),
			Vector2(side * 51.0, cap_y - 12.0)])
		draw_colored_polygon(leaf, LIME)
