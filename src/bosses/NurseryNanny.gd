extends "res://src/bosses/FloorGuardian.gd"
## An animated high chair that tips over its toy box, sweeps a dangling
## mobile just above the floor, and flings its dinner tray at two heights.

const PINK := Color(0.92, 0.52, 0.61)
const BLUE := Color(0.43, 0.75, 0.93)
const GOLD := Color(0.96, 0.73, 0.36)

var _winding_mobile := false
var _tray_ready := false
var _face := 1.0


func _ready() -> void:
	boss_id = &"nanny"
	display_name = "The Nursery Nanny"
	max_health = 57.0
	body_half_width = 63.0
	body_height = 145.0
	super._ready()


func _patterns() -> Array[Callable]:
	return [_mobile_sweep, _dinner_tray, _toy_tumble]


func _clear_attack() -> void:
	_winding_mobile = false
	_tray_ready = false
	super._clear_attack()


func _mobile_sweep() -> void:
	var token := _run_token
	var direction := -1.0 if dir_to_player() <= 0.0 else 1.0
	_face = direction
	_winding_mobile = true
	await telegraph(0.8, "Fold under the mobile")
	if not is_attack_current(token):
		return
	var destination := arena_rect.end.x - 96.0 if direction > 0.0 else arena_rect.position.x + 96.0
	var start := Vector2(global_position.x + direction * 73.0, arena_rect.end.y - 67.0)
	var speed := 330.0 if phase == 2 else 270.0
	var flight := maxf(0.45, absf(destination - start.x) / speed)
	add_hazard(start, Vector2(128, 60), Vector2(direction * speed, 0), BLUE, flight, 0.18)
	_winding_mobile = false
	await recover(0.91)


func _dinner_tray() -> void:
	var token := _run_token
	_face = -1.0 if dir_to_player() <= 0.0 else 1.0
	_tray_ready = true
	await telegraph(0.62, "Dinner tray")
	if not is_attack_current(token):
		return
	var origin := global_position + Vector2(_face * 59.0, -109.0)
	spawn_projectile(origin, Vector2(_face * 520.0, -190.0), GOLD, 13.0, &"tray")
	if phase == 2:
		await wait(0.34)
		if not is_attack_current(token):
			return
		spawn_projectile(origin, Vector2(_face * 580.0, -90.0), GOLD, 13.0, &"tray")
	_tray_ready = false
	await recover(1.0)


func _toy_tumble() -> void:
	var token := _run_token
	var target := player_floor_point()
	var offset := 140.0 if target.x < arena_rect.get_center().x else -140.0
	var points := PackedVector2Array([target, floor_point(target.x + offset)])
	await telegraph(0.68, "Toy box spill", points)
	for point in points:
		if not is_attack_current(token):
			return
		lob_to(global_position + Vector2(0, -87), point + Vector2(0, -14), 0.73, PINK, 14.0, &"cushion")
		await wait(0.18)
	await recover(0.92)


func _draw() -> void:
	var wood := hit_tint(Color(0.76, 0.53, 0.34))
	var cushion := hit_tint(PINK)
	for side in [-1.0, 1.0]:
		var hoof := Vector2(side * 52.0, -4)
		draw_line(Vector2(side * 32.0, -70), hoof, INK, 15.0, true)
		draw_line(Vector2(side * 32.0, -70), hoof, wood, 9.0, true)
	paint_plate(Rect2(-40, -50, 80, 10), wood)
	paint_plate(Rect2(-52, -71, 104, 15), wood)
	paint_plate(Rect2(-38, -141, 76, 69), wood)
	paint_plate(Rect2(-32, -134, 64, 46), cushion, 3.0)
	paint_eyes(Vector2(0, -119), 17.0, 8.0, dir_to_player())
	var tray_direction := _face if _tray_ready else 1.0
	paint_plate(Rect2(-52 + tray_direction * 9, -94, 104, 13), GOLD, 3.0)
	var mobile_offset := 20.0 * _face if _winding_mobile else 0.0
	var crossbar := Vector2(48.0 + mobile_offset, -116.0)
	draw_polyline(PackedVector2Array([Vector2(30, -106), Vector2(40, -153),
		crossbar + Vector2(0, -37), crossbar]), INK, 5.0, true)
	for i in 3:
		var at := crossbar + Vector2((i - 1.0) * 13.0, -4.0)
		var drop := at + Vector2(0, 12.0 if i == 1 else 7.0)
		draw_line(at, drop, INK, 2.0, true)
		draw_circle(drop, 5.0, BLUE if i == 1 else GOLD)
