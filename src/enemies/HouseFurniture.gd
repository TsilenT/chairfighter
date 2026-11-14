extends EnemyBase
## Local furniture with a visible wind-up and a locked attack direction.

enum Kind { CUSHION, PRINTER, TOOLBOX, CLOCK }

@export var kind := Kind.CUSHION

var _home: Vector2
var _time := 0.6
var _direction := 1.0
var _winding := false
var _phase := 0.0


func _ready() -> void:
	match kind:
		Kind.CUSHION:
			body_size = Vector2(54, 33)
		Kind.PRINTER:
			body_size = Vector2(54, 43)
		Kind.TOOLBOX:
			body_size = Vector2(51, 40)
		Kind.CLOCK:
			body_size = Vector2(40, 50)
			gravity_on = false
	super._ready()
	_home = global_position


func _ai(delta: float) -> void:
	_phase += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	var dx := 0.0
	var in_range := false
	if player != null and player.is_alive():
		dx = player.global_position.x - global_position.x
		in_range = absf(dx) < 350.0 and absf(player.global_position.y - global_position.y) < 105.0
	if kind == Kind.CLOCK:
		var bob := _home + Vector2(sin(_phase * 1.7) * 73, sin(_phase * 3.4) * 21)
		velocity = ((bob - global_position) * 3.0).limit_length(180.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
	if not in_range and not _winding:
		return
	_time -= delta
	if not _winding and _time <= 0.0:
		_direction = -1.0 if dx < 0.0 else 1.0
		_winding = true
		_time = 0.42
		Events.sfx_requested.emit(&"telegraph")
		return
	if not _winding or _time > 0.0:
		return
	_winding = false
	_time = 1.9
	match kind:
		Kind.CUSHION:
			if is_on_floor():
				velocity = Vector2(_direction * 285, -350)
		Kind.PRINTER:
			_shoot(Vector2(_direction * 340, -35), &"paper", 0.23)
		Kind.TOOLBOX:
			_shoot(Vector2(_direction * 283, -95), &"ball", 0.32)
		Kind.CLOCK:
			_shoot(Vector2(_direction * 145, 96), &"wave", 0.18)


func _shoot(speed: Vector2, style: StringName, gravity: float) -> void:
	var shot := Projectile.new()
	shot.velocity = speed
	shot.visual_style = style
	shot.gravity_scale = gravity
	shot.color = skin_color.lightened(0.48)
	shot.position = get_parent().to_local(global_position + Vector2(_direction * 26, -24))
	get_parent().add_child(shot)
	Events.sfx_requested.emit(&"lob")


func _draw_body() -> void:
	var dark := Color("#241d29")
	var lamp := Color("#ffce76") if _winding else skin_color.lightened(0.27)
	var body := Rect2(-body_size.x * 0.5, -body_size.y, body_size.x, body_size.y - 3)
	var frame := StyleBoxFlat.new()
	frame.bg_color = skin_color
	frame.set_corner_radius_all(12 if kind == Kind.CUSHION else 4)
	frame.border_color = dark
	frame.set_border_width_all(3)
	draw_style_box(frame, body)
	match kind:
		Kind.CUSHION:
			draw_arc(Vector2(0, -17), 15, 0.0, TAU, 18, lamp, 2, true)
		Kind.PRINTER:
			draw_rect(Rect2(-17, -12, 34, 5), dark)
			draw_rect(Rect2(-10, -20, 23, 15), lamp)
		Kind.TOOLBOX:
			draw_arc(Vector2(0, -39), 11, PI, TAU, 14, lamp, 4, true)
			draw_rect(Rect2(-24, -17, 48, 3), dark)
		Kind.CLOCK:
			draw_circle(Vector2(0, -22), 14, lamp)
			draw_line(Vector2(0, -22), Vector2(0, -22) + Vector2.from_angle(_phase * 4) * 11, dark, 2, true)
	for x in [-7.0, 7.0]:
		draw_circle(Vector2(x, -body_size.y + 10), 3.4, Color("#fef3e5"))
		draw_circle(Vector2(x + _direction * 1.4, -body_size.y + 10), 1.5, dark)
	if _winding:
		draw_arc(Vector2(0, -body_size.y * 0.5), 32, PI, TAU, 18, lamp, 3, true)
