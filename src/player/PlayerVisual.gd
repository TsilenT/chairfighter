class_name PlayerVisual
extends Node2D
## Code-drawn chair hero with per-form bodies, squash & stretch, walk rock,
## wheel spin (office), fold pose, and expressive eyes. Origin at the FEET.

var _form: FormDef = null
var _facing := 1.0
var _folded := false
var _squash := Vector2.ONE
var _rock := 0.0
var _walk_phase := 0.0
var _wheel_angle := 0.0
var _attack_flash := 0.0
var _blink_left := 0.0
var _hurt_flash := 0.0
var _dash_lean := 0.0

const OUTLINE := Color(0.16, 0.1, 0.07)


func set_form(form: FormDef) -> void:
	_form = form
	queue_redraw()


func set_facing(f: float) -> void:
	_facing = f


func set_folded(folded: bool) -> void:
	_folded = folded
	_squash = Vector2(1.3, 0.5) if folded else Vector2(0.8, 1.35)
	queue_redraw()


func play_jump() -> void:
	_squash = Vector2(0.78, 1.3)


func play_land(intensity: float = 1.0) -> void:
	_squash = Vector2(1.0 + 0.35 * intensity, 1.0 - 0.4 * intensity)


func play_attack() -> void:
	_attack_flash = 1.0
	_squash = Vector2(1.18, 0.92)


func play_hurt() -> void:
	_hurt_flash = 1.0


func update_motion(velocity: Vector2, on_floor: bool, delta: float) -> void:
	if on_floor and absf(velocity.x) > 20.0:
		_walk_phase += delta * absf(velocity.x) * 0.05
		_rock = sin(_walk_phase) * 0.09
	else:
		_rock = lerpf(_rock, 0.0, 10.0 * delta)
	_wheel_angle += velocity.x * delta * 0.03
	_dash_lean = lerpf(_dash_lean, -0.14 * signf(velocity.x) if absf(velocity.x) > 500.0 else 0.0, 8.0 * delta)
	_squash = _squash.lerp(Vector2.ONE, 12.0 * delta)
	_attack_flash = maxf(0.0, _attack_flash - delta * 6.0)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	_blink_left -= delta
	if _blink_left < -3.0:
		_blink_left = 0.12
	scale = Vector2(_squash.x * _facing, _squash.y)
	rotation = (_rock + _dash_lean * _facing) * _facing
	queue_redraw()


func _draw() -> void:
	if _form == null:
		return
	var base := _form.body_color
	if _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0:
		base = Color(1, 1, 1)
	if _folded:
		_draw_folded(base)
	else:
		match _form.id:
			&"armchair":
				_draw_armchair(base)
			&"office":
				_draw_office(base)
			&"folding":
				_draw_folding(base)
			_:
				_draw_basic(base)
	if _attack_flash > 0.0:
		var c := Color(1.0, 0.92, 0.4, _attack_flash * 0.85)
		draw_arc(Vector2(10, -26), _form.attack_range, -1.1, 1.1, 12, c, 5.0)


func _rounded(rect: Rect2, fill: Color, radius := 6.0, outline := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	if outline:
		sb.border_color = OUTLINE
		sb.set_border_width_all(2)
	sb.draw(get_canvas_item(), rect)


func _eyes(pos: Vector2, spacing := 10.0, r := 5.0) -> void:
	draw_circle(pos, r, Color.WHITE)
	draw_circle(pos + Vector2(spacing, 0), r, Color.WHITE)
	if _blink_left > 0.0:
		draw_rect(Rect2(pos.x - r, pos.y - 1.5, spacing + 2 * r, 3), OUTLINE)
	else:
		draw_circle(pos + Vector2(1.5, 0.5), r * 0.45, OUTLINE)
		draw_circle(pos + Vector2(spacing + 1.5, 0.5), r * 0.45, OUTLINE)


func _draw_folded(base: Color) -> void:
	_rounded(Rect2(-26, -18, 52, 16), base, 5.0)
	draw_circle(Vector2(20, -10), 3.5, base.darkened(0.35))
	# Peeking eyes on the front edge.
	_eyes(Vector2(-16, -10), 9.0, 3.0)


func _draw_basic(base: Color) -> void:
	var dark := base.darkened(0.35)
	# Legs.
	draw_rect(Rect2(-19, -14, 7, 14), dark)
	draw_rect(Rect2(12, -14, 7, 14), dark)
	# Seat + backrest (chunky enough to read at distance).
	_rounded(Rect2(-22, -24, 44, 12), base, 4.0)
	_rounded(Rect2(-26, -56, 14, 36), base.lightened(0.18), 5.0)
	# Cross rail (it's a sturdy chair).
	draw_rect(Rect2(-15, -8, 30, 4), dark)
	_eyes(Vector2(-16, -48))


func _draw_armchair(base: Color) -> void:
	var dark := base.darkened(0.3)
	# Plush base.
	_rounded(Rect2(-24, -20, 48, 18), dark, 7.0)
	# Big cushioned body.
	_rounded(Rect2(-22, -50, 34, 34), base, 10.0)
	# Padded arms (both sides, front one bigger).
	_rounded(Rect2(6, -36, 16, 30), base.lightened(0.12), 8.0)
	_rounded(Rect2(-26, -38, 12, 32), base.lightened(0.08), 8.0)
	# Button tuft.
	draw_circle(Vector2(-6, -34), 2.6, dark)
	_eyes(Vector2(-12, -42))


func _draw_office(base: Color) -> void:
	var teal := Color(0.25, 0.65, 0.62)
	# Star base + wheels that actually spin.
	draw_line(Vector2(-16, -6), Vector2(16, -6), base.lightened(0.25), 5.0)
	for wx in [-14.0, 14.0]:
		draw_circle(Vector2(wx, -5), 5.5, Color(0.18, 0.18, 0.2))
		draw_circle(Vector2(wx, -5), 5.5, OUTLINE, false, 1.5)
		var spoke := Vector2(cos(_wheel_angle), sin(_wheel_angle)) * 4.0
		draw_line(Vector2(wx, -5) - spoke, Vector2(wx, -5) + spoke, Color(0.6, 0.6, 0.65), 1.5)
	# Gas lift column.
	draw_rect(Rect2(-3, -22, 6, 16), Color(0.55, 0.58, 0.62))
	# Seat + tilted back with headrest.
	_rounded(Rect2(-20, -30, 40, 10), base, 5.0)
	_rounded(Rect2(-24, -58, 11, 30), base.lightened(0.15), 6.0)
	_rounded(Rect2(-25, -64, 13, 8), teal, 4.0)  # headrest accent
	_eyes(Vector2(-15, -50))


func _draw_folding(base: Color) -> void:
	var steel := base.darkened(0.2)
	# X-brace legs.
	draw_line(Vector2(-16, 0), Vector2(10, -20), steel, 4.0)
	draw_line(Vector2(14, 0), Vector2(-12, -20), steel, 4.0)
	# Thin seat + slatted back.
	_rounded(Rect2(-20, -24, 40, 7), base, 3.0)
	_rounded(Rect2(-22, -54, 8, 32), base.lightened(0.1), 3.0)
	draw_line(Vector2(-18, -48), Vector2(-18, -26), Color(1, 1, 1, 0.25), 2.0)  # sheen
	_eyes(Vector2(-13, -47))
