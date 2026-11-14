extends "res://src/bosses/FloorGuardian.gd"
## A cast-iron boiler built into a reclining chair. Each vent commits to
## marked positions before the pressure gauge drops and leaves an opening.

const STEAM := Color(0.56, 0.88, 0.96)
const EMBER := Color(0.98, 0.45, 0.24)

var _pressure := 0.0
var _valve_direction := 0.0


func _ready() -> void:
	boss_id = &"boiler"
	display_name = "The Boiler Foreman"
	max_health = 42.0
	body_half_width = 64.0
	body_height = 123.0
	super._ready()


func _patterns() -> Array[Callable]:
	return [_vent_cycle, _pressure_release, _slag_fall]


func _clear_attack() -> void:
	_pressure = 0.0
	_valve_direction = 0.0
	super._clear_attack()


func _vent_cycle() -> void:
	var token := _run_token
	var target := player_floor_point()
	var points := PackedVector2Array([target])
	if phase == 2:
		var toward_center := 1.0 if target.x < arena_rect.get_center().x else -1.0
		points.append(floor_point(target.x + toward_center * 172.0))
	_pressure = 1.0
	await telegraph(0.74, "Steam vents", points)
	if not is_attack_current(token):
		return
	for point in points:
		add_hazard(point + Vector2(0, -105), Vector2(58, 210), Vector2.ZERO, STEAM, 0.53)
	Events.sfx_requested.emit(&"break")
	_pressure = 0.0
	await recover(0.88)


func _pressure_release() -> void:
	var token := _run_token
	_valve_direction = -1.0 if dir_to_player() <= 0.0 else 1.0
	_pressure = 0.8
	await telegraph(0.69, "Pressure wave")
	if not is_attack_current(token):
		return
	var launch := Vector2(global_position.x + _valve_direction * 78.0, arena_rect.end.y - 33.0)
	add_hazard(launch, Vector2(62, 52), Vector2(_valve_direction * 430.0, 0.0), STEAM, 1.7)
	if phase == 2:
		await wait(0.22)
		if not is_attack_current(token):
			return
		add_hazard(launch, Vector2(50, 38), Vector2(_valve_direction * 350.0, 0.0), STEAM, 1.6)
	_pressure = 0.0
	_valve_direction = 0.0
	await recover(0.8)


func _slag_fall() -> void:
	var token := _run_token
	var floor_target := player_floor_point()
	var inward := 1.0 if floor_target.x < arena_rect.get_center().x else -1.0
	var points := PackedVector2Array([floor_target, floor_point(floor_target.x + inward * 130.0)])
	_pressure = 0.65
	await telegraph(0.65, "Rivet spill", points)
	for point in points:
		if not is_attack_current(token):
			return
		lob_to(global_position + Vector2(0, -body_height - 2.0), point + Vector2(0, -10),
				0.78, EMBER, 12.0, &"ball")
		await wait(0.14)
	_pressure = 0.0
	await recover(0.82)


func _draw() -> void:
	var steel := hit_tint(Color(0.31, 0.36, 0.4))
	var bronze := hit_tint(Color(0.65, 0.43, 0.24))
	var warm := EMBER.lerp(Color(0.97, 0.8, 0.29), 1.0 - _pressure)
	paint_plate(Rect2(-47, -35, 94, 26), steel)
	for foot in [-47.0, 47.0]:
		draw_line(Vector2(foot, -18), Vector2(foot * 1.12, -2), INK, 13.0, true)
		draw_line(Vector2(foot, -17), Vector2(foot * 1.1, -4), bronze, 7.0, true)
	paint_plate(Rect2(-54, -112, 108, 89), steel)
	paint_plate(Rect2(-63, -79, 14, 37), bronze)
	paint_plate(Rect2(49, -79, 14, 37), bronze)
	paint_plate(Rect2(-17, -123, 34, 14), bronze)
	paint_plate(Rect2(-32, -71, 64, 42), bronze.darkened(0.28))
	for slot in [-20.0, -6.0, 6.0, 20.0]:
		draw_line(Vector2(slot, -61), Vector2(slot, -39), INK, 7.0, true)
		draw_line(Vector2(slot, -59), Vector2(slot, -42), warm, 3.0, true)
	paint_eyes(Vector2(0, -95), 18.0, 8.0, dir_to_player())
	var gauge := Vector2(-43, -71)
	draw_circle(gauge, 15.0, INK)
	draw_circle(gauge, 12.0, Color(0.93, 0.85, 0.66))
	var angle := lerpf(-2.6, -0.52, _pressure)
	draw_line(gauge, gauge + Vector2.from_angle(angle) * 9.0, EMBER.darkened(0.2), 2.8, true)
	if _valve_direction != 0.0:
		var at := Vector2(_valve_direction * 62.0, -50)
		draw_polyline(PackedVector2Array([at + Vector2(0, -9), at + Vector2(_valve_direction * 13.0, 0),
			at + Vector2(0, 9)]), STEAM, 4.0, true)
