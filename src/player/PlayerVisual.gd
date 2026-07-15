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
var _attack_style: StringName = &"body_bash"
var _attack_phase := 0.0
var _blink_left := 0.0
var _hurt_flash := 0.0
var _block_flash := 0.0
var _dash_lean := 0.0
var _charge := 0.0
var _charge_phase := 0.0
var _braced := false
var _spinning := false
var _special_phase := 0.0

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


func play_attack(style: StringName = &"") -> void:
	_attack_style = style if style != &"" else (_form.attack_style if _form != null else &"body_bash")
	_attack_flash = 1.0
	_attack_phase = 0.0
	match _attack_style:
		&"arm_punch", &"footrest_kick", &"tray_shove", &"tray_toss":
			_squash = Vector2(1.24, 0.92)
		&"hinge_snap", &"leg_kick":
			_squash = Vector2(1.1, 0.84)
		&"rocker_sweep", &"stool_spin", &"swivel_ram":
			_squash = Vector2(1.22, 0.86)
		_:
			_squash = Vector2(1.3, 0.9)


func play_hurt() -> void:
	_hurt_flash = 1.0


func play_block() -> void:
	_block_flash = 1.0
	_squash = Vector2(0.86, 1.1)


func set_braced(value: bool) -> void:
	_braced = value
	queue_redraw()


func set_spinning(value: bool) -> void:
	_spinning = value
	queue_redraw()


## Rocking charge 0..1: drives an accelerating rock oscillation.
func set_charge(amount: float) -> void:
	_charge = amount


func update_motion(velocity: Vector2, on_floor: bool, delta: float) -> void:
	if on_floor and absf(velocity.x) > 20.0:
		_walk_phase += delta * absf(velocity.x) * 0.05
		_rock = sin(_walk_phase) * 0.09
	else:
		_rock = lerpf(_rock, 0.0, 10.0 * delta)
	_wheel_angle += velocity.x * delta * 0.03
	_dash_lean = lerpf(_dash_lean, -0.14 * signf(velocity.x) if absf(velocity.x) > 500.0 else 0.0, 8.0 * delta)
	_squash = _squash.lerp(Vector2.ONE, 12.0 * delta)
	if _attack_flash > 0.0:
		_attack_phase += delta * 8.0
	_attack_flash = maxf(0.0, _attack_flash - delta * 5.0)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	_block_flash = maxf(0.0, _block_flash - delta * 7.0)
	_blink_left -= delta
	if _blink_left < -3.0:
		_blink_left = 0.12
	if _charge > 0.0:
		_charge_phase += delta * (6.0 + 10.0 * _charge)
		_rock = sin(_charge_phase) * (0.12 + 0.22 * _charge)
	if _spinning:
		_special_phase += delta * 18.0
		_rock = sin(_special_phase * 2.0) * 0.05
	if _braced:
		_rock = lerpf(_rock, -0.13, 10.0 * delta)
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
			&"recliner":
				_draw_recliner(base)
			&"office":
				_draw_office(base)
			&"barstool":
				_draw_barstool(base)
			&"folding":
				_draw_folding(base)
			&"highchair":
				_draw_highchair(base)
			&"rocking":
				_draw_rocking(base)
			&"stool":
				_draw_stool(base)
			_:
				_draw_basic(base)
	if _attack_flash > 0.0:
		_draw_primary_attack(base)


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


func _draw_recliner(base: Color) -> void:
	var dark := base.darkened(0.34)
	# Broad planted base and the unmistakable reclined padded back.
	_rounded(Rect2(-25, -18, 50, 16), dark, 7.0)
	var back := PackedVector2Array([
		Vector2(-25, -55), Vector2(-10, -58), Vector2(5, -29), Vector2(-13, -21),
	])
	draw_colored_polygon(back, base)
	draw_polyline(PackedVector2Array([back[0], back[1], back[2], back[3], back[0]]), OUTLINE, 2.0)
	_rounded(Rect2(-10, -31, 35, 15), base.lightened(0.1), 6.0)
	# Resting footrest: the primary attack visibly kicks this piece outward.
	_rounded(Rect2(16, -22, 17, 10), base.lightened(0.18), 5.0)
	_eyes(Vector2(-16, -48), 9.0, 4.5)
	if _braced:
		draw_line(Vector2(-20, -4), Vector2(-29, 0), dark, 5.0)
		draw_line(Vector2(18, -4), Vector2(29, 0), dark, 5.0)
		draw_arc(Vector2(19, -29), 25.0, -1.25, 1.25, 12,
				Color(1.0, 0.82, 0.35, 0.45 + 0.35 * _block_flash), 4.0)


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


func _draw_barstool(base: Color) -> void:
	var dark := base.darkened(0.38)
	# Round seat, single swivel post, foot ring, and splayed feet.
	draw_circle(Vector2(0, -42), 21.0, OUTLINE)
	draw_circle(Vector2(0, -43), 18.0, base)
	draw_rect(Rect2(-3, -31, 6, 25), dark)
	draw_arc(Vector2(0, -21), 15.0, 0.0, TAU, 20, base.lightened(0.2), 3.0)
	var phase := _special_phase if _spinning else _wheel_angle * 0.25
	for i in 3:
		var a := phase + TAU * float(i) / 3.0
		var foot := Vector2(cos(a) * 23.0, -4.0 + sin(a) * 3.0)
		draw_line(Vector2(0, -8), foot, dark, 4.0)
		draw_circle(foot, 3.0, dark)
	_eyes(Vector2(-8, -47), 9.0, 4.0)
	if _spinning:
		for r in [28.0, 34.0]:
			draw_arc(Vector2(0, -28), r, _special_phase, _special_phase + 1.7,
					10, Color(1.0, 0.8, 0.3, 0.6), 3.0)


func _draw_rocking(base: Color) -> void:
	var dark := base.darkened(0.3)
	# Curved rockers.
	draw_arc(Vector2(0, -8), 24.0, 0.35, PI - 0.35, 14, dark, 5.0)
	# Seat + tall spindled back.
	_rounded(Rect2(-20, -26, 40, 10), base, 4.0)
	_rounded(Rect2(-24, -60, 11, 40), base.lightened(0.12), 5.0)
	for i in 3:
		draw_line(Vector2(-13 + i * 9, -52), Vector2(-13 + i * 9, -26), dark, 2.5)
	# Cozy blanket corner.
	_rounded(Rect2(2, -34, 16, 9), Color(0.62, 0.3, 0.3), 4.0, false)
	# Charge glow when rocking up.
	if _charge > 0.0:
		var glow := Color(1.0, 0.8, 0.35, 0.25 + 0.35 * _charge)
		draw_circle(Vector2(0, -28), 30.0 + 8.0 * _charge, glow)
	_eyes(Vector2(-16, -52))


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


func _draw_highchair(base: Color) -> void:
	var dark := base.darkened(0.34)
	# Tall, narrow legs make the oversized detachable tray read immediately.
	draw_line(Vector2(-13, -31), Vector2(-20, 0), dark, 5.0)
	draw_line(Vector2(13, -31), Vector2(20, 0), dark, 5.0)
	draw_line(Vector2(-17, -10), Vector2(17, -10), dark, 3.0)
	_rounded(Rect2(-18, -39, 36, 10), base, 4.0)
	_rounded(Rect2(-20, -60, 12, 25), base.lightened(0.12), 5.0)
	# The tray is a proper piece of the chair, not a generic hand projectile.
	_rounded(Rect2(3, -43, 31, 9), base.lightened(0.22), 4.0)
	draw_line(Vector2(8, -34), Vector2(8, -28), dark, 3.0)
	_eyes(Vector2(-13, -53), 8.0, 4.0)


func _draw_stool(base: Color) -> void:
	var dark := base.darkened(0.38)
	# Compact springy chassis: cushion, visible coil, and three kickable legs.
	_rounded(Rect2(-21, -43, 42, 11), base, 6.0)
	draw_line(Vector2(-13, -33), Vector2(-19, 0), dark, 5.0)
	draw_line(Vector2(13, -33), Vector2(19, 0), dark, 5.0)
	for y in [-29.0, -24.0, -19.0, -14.0]:
		draw_line(Vector2(-5, y), Vector2(5, y + 3.0), base.lightened(0.28), 2.0)
	_eyes(Vector2(-8, -39), 9.0, 3.8)


func _draw_primary_attack(base: Color) -> void:
	# A smooth wind-up/contact/recover pulse shared by the authored pieces.
	var amount := sin(clampf(1.0 - _attack_flash, 0.0, 1.0) * PI)
	var flash := Color(1.0, 0.86, 0.32, 0.35 + 0.5 * amount)
	var dark := base.darkened(0.34)
	match _attack_style:
		&"arm_punch":
			var length := 18.0 + amount * 62.0
			_rounded(Rect2(8, -35, length, 13), base.lightened(0.18), 6.0)
			draw_circle(Vector2(8 + length, -28.5), 9.0, OUTLINE)
			draw_circle(Vector2(8 + length, -28.5), 6.5, base.lightened(0.25))
		&"swivel_ram":
			for r in [28.0, 38.0, 47.0]:
				draw_arc(Vector2(0, -28), r, _attack_phase + r * 0.03,
						_attack_phase + r * 0.03 + 1.45, 9, flash, 3.0)
			draw_line(Vector2(-22, -5), Vector2(31 + amount * 15.0, -5), flash, 5.0)
		&"hinge_snap":
			var hinge := Vector2(15, -21)
			var angle := lerpf(-1.45, -0.1, amount)
			var tip := hinge + Vector2(cos(angle), sin(angle)) * 47.0
			draw_line(hinge, tip, OUTLINE, 10.0)
			draw_line(hinge, tip, base.lightened(0.2), 6.0)
			draw_circle(tip, 5.0, flash)
		&"rocker_sweep":
			var end_x := 37.0 + amount * 25.0
			draw_arc(Vector2(5, -8), end_x, 0.1, 0.72, 16, dark, 6.0)
			for x in [31.0, 46.0, 59.0]:
				draw_line(Vector2(x, -4), Vector2(x + 9.0, -1), flash, 3.0)
		&"footrest_kick":
			var extension := 18.0 + amount * 68.0
			draw_line(Vector2(15, -24), Vector2(extension, -18), dark, 7.0)
			_rounded(Rect2(extension - 5.0, -27, 25, 18), base.lightened(0.2), 6.0)
		&"stool_spin":
			for i in 3:
				var a := _attack_phase * 2.5 + TAU * float(i) / 3.0
				var tip := Vector2(cos(a) * (28.0 + 17.0 * amount), -22 + sin(a) * 16.0)
				draw_line(Vector2(0, -25), tip, dark, 5.0)
				draw_circle(tip, 4.0, flash)
		&"tray_shove":
			var tray_x := 9.0 + amount * 45.0
			draw_line(Vector2(8, -35), Vector2(tray_x, -35), dark, 4.0)
			_rounded(Rect2(tray_x, -43, 43, 10), base.lightened(0.24), 4.0)
		&"tray_toss":
			var toss_x := 28.0 + amount * 35.0
			_rounded(Rect2(toss_x, -48 - amount * 8.0, 36, 9), base.lightened(0.3), 4.0)
			draw_line(Vector2(20, -39), Vector2(toss_x, -43), flash, 3.0)
		&"leg_kick":
			var kick_tip := Vector2(28.0 + amount * 32.0, -6.0 - amount * 9.0)
			draw_line(Vector2(7, -29), kick_tip, OUTLINE, 8.0)
			draw_line(Vector2(7, -29), kick_tip, base.darkened(0.15), 4.0)
			draw_circle(kick_tip, 5.0, flash)
		_: # Basic body bash: the whole chair is the weapon.
			for y in [-42.0, -27.0, -12.0]:
				draw_line(Vector2(-29 - amount * 9.0, y), Vector2(-12, y), flash, 3.0)
			draw_line(Vector2(23, -45), Vector2(32 + amount * 10.0, -34), flash, 4.0)
			draw_line(Vector2(23, -9), Vector2(34 + amount * 12.0, -14), flash, 4.0)
