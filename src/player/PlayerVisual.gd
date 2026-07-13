class_name PlayerVisual
extends Node2D
## Code-drawn chair body with squash & stretch, walk rock, fold pose, and
## expressive eyes. Origin sits at the player's FEET (y=0). Phase 4 may
## swap the _draw body for SVG sprites; the animation hooks stay the same.

var _form: FormDef = null
var _facing := 1.0
var _folded := false
var _squash := Vector2.ONE      # target-driven, eases back to ONE
var _rock := 0.0                # walk wobble angle
var _walk_phase := 0.0
var _attack_flash := 0.0
var _blink_left := 0.0
var _hurt_flash := 0.0


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
	_squash = _squash.lerp(Vector2.ONE, 12.0 * delta)
	_attack_flash = maxf(0.0, _attack_flash - delta * 6.0)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	_blink_left -= delta
	if _blink_left < -3.0:
		_blink_left = 0.12
	scale = Vector2(_squash.x * _facing, _squash.y)
	rotation = _rock * _facing
	queue_redraw()


func _draw() -> void:
	if _form == null:
		return
	var base := _form.body_color
	if _hurt_flash > 0.0 and int(_hurt_flash * 12.0) % 2 == 0:
		base = Color(1, 1, 1)
	var dark := base.darkened(0.35)
	var light := base.lightened(0.18)
	var outline := Color(0.16, 0.1, 0.07)

	if _folded:
		# Flat slab with a little handle nub.
		_rounded(Rect2(-26, -18, 52, 16), base, outline)
		draw_circle(Vector2(20, -10), 3.5, dark)
		return

	# Legs.
	draw_rect(Rect2(-18, -14, 6, 14), dark)
	draw_rect(Rect2(12, -14, 6, 14), dark)
	# Seat.
	_rounded(Rect2(-22, -22, 44, 10), base, outline)
	# Backrest (behind = -x side).
	_rounded(Rect2(-24, -56, 10, 38), light, outline)
	# Eyes on the backrest top — the chair's face.
	var eye_y := -48.0
	draw_circle(Vector2(-14, eye_y), 5.0, Color.WHITE)
	draw_circle(Vector2(-4, eye_y), 5.0, Color.WHITE)
	if _blink_left > 0.0:
		draw_rect(Rect2(-19, eye_y - 1.5, 20, 3), outline)
	else:
		draw_circle(Vector2(-12.5, eye_y), 2.2, outline)
		draw_circle(Vector2(-2.5, eye_y), 2.2, outline)
	# Attack flash: swipe arc in front.
	if _attack_flash > 0.0:
		var reach := _form.attack_range
		var c := Color(1.0, 0.92, 0.4, _attack_flash * 0.85)
		draw_arc(Vector2(10, -26), reach, -1.1, 1.1, 12, c, 5.0)


func _rounded(rect: Rect2, fill: Color, outline: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, 2.5)
