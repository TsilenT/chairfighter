extends Node2D
## Workshop fixture with its origin at floor level. The doorway reads the
## outcome flag. A reflected shot, frontal block, or tray impact operates
## the fixture through the same combat interactions used in the house.

const STANCE := Rect2(-195, -12, 85, 12)
const LAUNCH_POINT := Vector2(-14, -32)
const REFLECT_TARGET := Vector2(-19, -64)
const TRAY_TARGET := Vector2(-22, -59)
const CHARGE_TIME := 0.8
const RETRY_TIME := 1.65
const COLORS := {&"brace": Color("#e4ad76"), &"spin": Color("#89d8cf"), &"toss": Color("#e6aa94")}
const RELEASED_COLOR := Color("#a4ca93")
const OUTLINE := Color("#211a1e")
const CAPTIONS := {
	&"brace": "AIR-PRESSURE RELIEF\nFace the piston and brace.",
	&"spin": "RETURN-SHOT BELL\nSpin to send the shot back into the bell.",
	&"toss": "TRAY CATCH\nStand on the mark and toss into the catch.",
}

@export_enum("brace", "spin", "toss") var mechanic: String = "brace"
@export var clear_flag: String = ""

var _complete := false
var _prompt: Label
var _player: Player
var _shot: Projectile
var _windup := CHARGE_TIME
var _charging := false


func _ready() -> void:
	_complete = not clear_flag.is_empty() and GameState.has_flag(clear_flag)
	if _complete or clear_flag.is_empty():
		set_physics_process(false)
		return
	_build_prompt()
	if mechanic == "spin":
		_build_target(REFLECT_TARGET, Vector2(28, 74))
	elif mechanic == "toss":
		_build_target(TRAY_TARGET, Vector2(26, 26))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player != null and mechanic == "brace":
			_player.braced_hit.connect(_on_braced_hit)
	if _player == null or not _player.is_alive():
		_prompt.hide()
		_reset_launcher()
		return
	var feet := to_local(_player.global_position)
	_prompt.visible = feet.x >= -260 and feet.x <= 36 and absf(feet.y) < 110
	if mechanic == "toss":
		return
	if feet.x < STANCE.position.x - 10 or feet.x > STANCE.end.x + 10 or absf(feet.y) > 72:
		_reset_launcher()
		return
	if not _charging:
		_charging = true
		Events.sfx_requested.emit(&"telegraph")
	var before_windup := _windup
	_windup -= delta
	if before_windup > CHARGE_TIME and _windup <= CHARGE_TIME:
		Events.sfx_requested.emit(&"telegraph")
	if _windup <= 0:
		_remove_shot()
		_launch_shot()
		_windup = RETRY_TIME
	queue_redraw()


func _reset_launcher() -> void:
	if not _charging:
		return
	_charging = false
	_windup = CHARGE_TIME
	_remove_shot()
	queue_redraw()


func _remove_shot() -> void:
	if is_instance_valid(_shot):
		_shot.queue_free()
	_shot = null


func _launch_shot() -> void:
	_shot = Projectile.new()
	_shot.position = LAUNCH_POINT
	_shot.velocity = Vector2(-265, 0)
	_shot.gravity_scale = 0.0
	# The Workshop trials do not cost a heart.
	_shot.damage = 0.0
	_shot.knockback_strength = 105.0
	_shot.color = COLORS[StringName(mechanic)].lightened(0.24)
	_shot.visual_style = &"wave" if mechanic == "brace" else &"ball"
	add_child(_shot)
	Events.sfx_requested.emit(&"lob")


func _on_braced_hit(hitbox: Hitbox) -> void:
	if is_instance_valid(_shot) and hitbox.get_parent() == _shot:
		_release()


func _build_target(center: Vector2, size: Vector2) -> void:
	var target := Hurtbox.new()
	target.position = center
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	target.add_child(collision)
	target.hit_received.connect(_on_target_hit)
	add_child(target)


func _on_target_hit(hitbox: Hitbox) -> void:
	if _complete or hitbox.faction != &"player":
		return
	var projectile := hitbox.get_parent() as Projectile
	if projectile == null:
		return
	if mechanic == "spin" and projectile != _shot:
		return
	if mechanic == "toss" and not projectile.is_player_tray:
		return
	projectile.queue_free()
	_release()


func _release() -> void:
	if _complete:
		return
	_complete = true
	GameState.set_flag(clear_flag)
	_remove_shot()
	_prompt.hide()
	set_physics_process(false)
	Events.sfx_requested.emit(&"gate_open")
	queue_redraw()


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.position = Vector2(-269, -137)
	_prompt.size = Vector2(240, 60)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_color", COLORS[StringName(mechanic)].lightened(0.38))
	_prompt.add_theme_color_override("font_outline_color", OUTLINE)
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.text = CAPTIONS[StringName(mechanic)]
	_prompt.hide()
	add_child(_prompt)


func _draw() -> void:
	var color: Color = COLORS[StringName(mechanic)]
	if _complete:
		color = RELEASED_COLOR
	else:
		draw_rect(STANCE, color.darkened(0.6))
		draw_rect(Rect2(STANCE.position, Vector2(STANCE.size.x, 3)), color)
		for x in range(-185, -120, 15):
			draw_line(Vector2(x, -6), Vector2(x + 6, -11), OUTLINE, 2)
	match mechanic:
		"brace":
			_draw_launcher(color)
			_draw_pressure_gauge(Vector2(13, -68), color)
		"spin":
			_draw_launcher(color)
			_draw_bell(color)
		"toss":
			_draw_tray_catch(color)


func _draw_launcher(color: Color) -> void:
	var charge := 0.0
	if _charging and not _complete:
		charge = 1.0 - clampf(_windup / CHARGE_TIME, 0, 1)
	var housing := Rect2(-16, -47, 42, 30)
	draw_line(Vector2(24, -31), Vector2(58, -31), color.darkened(0.3), 5.0)
	draw_rect(housing, color.darkened(0.58))
	draw_rect(housing, color, false, 2.0)
	draw_rect(Rect2(-18.0 - 9.0 * charge, -40, 10.0 + 9.0 * charge, 16), color.lightened(0.15 + 0.35 * charge))
	if charge > 0.4:
		draw_line(Vector2(-30, -32), Vector2(-106, -32), Color(color, 0.12 + 0.42 * charge), 2.0)


func _draw_pressure_gauge(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(0, 15), center + Vector2(0, 22), color, 4.0)
	draw_circle(center, 16.0, OUTLINE)
	draw_arc(center, 14.0, PI, TAU, 18, color.lightened(0.3), 2.5, true)
	var pressure_direction := Vector2(0.65, -0.76) if not _complete else Vector2(-0.86, -0.51)
	draw_line(center, center + pressure_direction * 11.0, color, 2.5, true)
	draw_circle(center, 3.0, color)


func _draw_bell(color: Color) -> void:
	var center := REFLECT_TARGET + Vector2(0, -13)
	draw_line(center + Vector2(18, -3), center + Vector2(45, -3), color.darkened(0.3), 5.0)
	draw_circle(center, 16.0, OUTLINE)
	draw_circle(center, 13.0, color.darkened(0.24))
	draw_arc(center, 11.0, PI, TAU, 14, color.lightened(0.38), 3.0, true)
	draw_line(center + Vector2(-15, 6), center + Vector2(15, 6), color, 3.0)
	draw_circle(center + Vector2(0, 9), 4.0, color.lightened(0.27))


func _draw_tray_catch(color: Color) -> void:
	var center := TRAY_TARGET
	draw_line(center + Vector2(11, 0), center + Vector2(53, 0), color.darkened(0.3), 5.0)
	draw_rect(Rect2(center - Vector2(14, 13), Vector2(28, 26)), OUTLINE)
	draw_arc(center, 12.0, -PI * 0.5, PI * 0.5, 12, color, 4.0, true)
	draw_line(center + Vector2(-16, 11), center + Vector2(5, 11), color, 4.0)
	if _complete:
		draw_line(center + Vector2(-17, 4), center + Vector2(8, 4), color.lightened(0.3), 4.0)
