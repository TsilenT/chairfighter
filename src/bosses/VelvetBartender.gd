extends "res://src/bosses/FloorGuardian.gd"
## The bar cart alternates between shots you jump over and a serving tray
## you can run beneath. A tip jar volley breaks up the horizontal patterns.

const VELVET := Color(0.39, 0.19, 0.44)
const MINT := Color(0.55, 0.93, 0.7)
const AMBER := Color(0.96, 0.71, 0.32)

var _face := 1.0
var _tray_y := -54.0
var _serving := false


func _ready() -> void:
	boss_id = &"bartender"
	display_name = "The Velvet Bartender"
	max_health = 52.0
	body_half_width = 63.0
	body_height = 126.0
	super._ready()


func _patterns() -> Array[Callable]:
	return [_slide_coasters, _high_service, _tip_jar]


func _clear_attack() -> void:
	_serving = false
	super._clear_attack()


func _slide_coasters() -> void:
	var token := _run_token
	_face = -1.0 if dir_to_player() <= 0.0 else 1.0
	_tray_y = -28.0
	_serving = true
	await telegraph(0.7, "Jump the coasters")
	var count := 3 if phase == 2 else 2
	for coaster in count:
		if not is_attack_current(token):
			return
		var start := global_position + Vector2(_face * 54.0, -23.0)
		add_hazard(start, Vector2(56.0, 22.0), Vector2(_face * (380.0 + coaster * 61.0), 0.0),
				AMBER, 1.8)
		await wait(0.33)
	_serving = false
	await recover(0.82)


func _high_service() -> void:
	var token := _run_token
	_face = -1.0 if dir_to_player() <= 0.0 else 1.0
	_tray_y = -103.0
	_serving = true
	await telegraph(0.62, "Run under the tray")
	if not is_attack_current(token):
		return
	var start := global_position + Vector2(_face * 64.0, _tray_y)
	add_hazard(start, Vector2(142, 23), Vector2(_face * 320.0, 0.0), MINT, 1.8)
	_serving = false
	await recover(0.9)


func _tip_jar() -> void:
	var token := _run_token
	var point := player_floor_point()
	var inward := -1.0 if point.x > arena_rect.get_center().x else 1.0
	var points := PackedVector2Array([point, floor_point(point.x + inward * 126.0)])
	if phase == 2:
		points.append(floor_point(point.x + inward * 246.0))
	await telegraph(0.62, "Tip jar toss", points)
	for target in points:
		if not is_attack_current(token):
			return
		lob_to(global_position + Vector2(0, -109), target + Vector2(0, -15), 0.81, AMBER, 12.0, &"tray")
		await wait(0.16)
	await recover(0.84)


func _draw() -> void:
	var wood := hit_tint(Color(0.45, 0.31, 0.27))
	var velvet := hit_tint(VELVET)
	for side in [-1.0, 1.0]:
		var wheel := Vector2(side * 40.0, -13)
		draw_circle(wheel, 13.0, INK)
		draw_circle(wheel, 7.0, AMBER.darkened(0.25))
		draw_line(Vector2(side * 40.0, -18), Vector2(side * 46.0, -74), wood, 10.0, true)
	paint_plate(Rect2(-58, -47, 116, 12), wood)
	paint_plate(Rect2(-58, -87, 116, 16), velvet)
	paint_plate(Rect2(-47, -124, 94, 47), velvet)
	paint_plate(Rect2(-39, -115, 78, 29), velvet.lightened(0.15), 3.0)
	paint_eyes(Vector2(0, -102), 19.0, 7.0, dir_to_player())
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(0, -71), Vector2(side * 12.0, -77),
			Vector2(side * 12.0, -64)])
		draw_colored_polygon(wing, MINT)
	draw_circle(Vector2(0, -71), 3.5, MINT.darkened(0.13))
	for glass in [-27.0, 18.0]:
		paint_plate(Rect2(glass, -61, 9, 13), AMBER if phase == 2 else MINT, 2.0)
	if _serving:
		var start := Vector2(_face * 42.0, _tray_y)
		var end := Vector2(_face * 88.0, _tray_y)
		draw_line(start, end, INK, 12.0, true)
		draw_line(start, end, AMBER if _tray_y > -60.0 else MINT, 7.0, true)
