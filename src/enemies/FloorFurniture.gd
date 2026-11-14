extends EnemyBase
## These four floor enemies give each route a small encounter before its
## guardian. Trolleys patrol, rocking horses hop, and the register and
## planter have different lobs so furniture reads as part of the room.

enum Role { REGISTER, TROLLEY, ROCKING_HORSE, PLANTER }

const INK := Color(0.10, 0.083, 0.11)
const EYE := Color(0.98, 0.91, 0.73)

@export var role := Role.REGISTER

var _home_x := 0.0
var _direction := 1.0
var _timer := 0.8
var _flash := false
var _wheel_angle := 0.0


func _ready() -> void:
	_home_x = global_position.x
	match role:
		Role.REGISTER:
			body_size = Vector2(52, 37)
			skin_color = Color(0.42, 0.49, 0.49)
		Role.TROLLEY:
			body_size = Vector2(42, 44)
			skin_color = Color(0.61, 0.37, 0.52)
		Role.ROCKING_HORSE:
			body_size = Vector2(45, 42)
			skin_color = Color(0.72, 0.46, 0.31)
		Role.PLANTER:
			body_size = Vector2(43, 45)
			skin_color = Color(0.74, 0.38, 0.32)
	super._ready()


func _ai(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_timer -= delta
	match role:
		Role.REGISTER:
			velocity.x = 0.0
			_lob_at_player(player, Color(0.96, 0.57, 0.26), &"ball", 320.0, -240.0)
		Role.TROLLEY:
			_patrol(100.0, 95.0)
			_wheel_angle += delta * velocity.x / 10.0
		Role.ROCKING_HORSE:
			_patrol(68.0, 82.0)
			if _timer < 0.0 and is_on_floor():
				velocity.y = -270.0
				_timer = 0.94
		Role.PLANTER:
			velocity.x = 0.0
			_lob_at_player(player, Color(0.75, 0.87, 0.4), &"yarn", 240.0, -340.0)


func _patrol(distance: float, speed: float) -> void:
	var beyond_turn := (global_position.x - _home_x) * _direction >= distance
	if beyond_turn or is_on_wall():
		_direction *= -1.0
	velocity.x = _direction * speed


func _lob_at_player(player: Node2D, color: Color, style: StringName,
		speed: float, lift: float) -> void:
	if player == null or absf(player.global_position.x - global_position.x) > 410.0 \
			or absf(player.global_position.y - global_position.y) > 210.0:
		_flash = false
		_timer = 0.4
		return
	if not _flash:
		_direction = 1.0 if player.global_position.x >= global_position.x else -1.0
		if _timer < 0.35:
			_flash = true
	if _timer > 0.0:
		return
	var shot := Projectile.new()
	shot.color = color
	shot.radius = 8.0
	shot.visual_style = style
	shot.velocity = Vector2(_direction * speed, lift)
	shot.position = Vector2(_direction * 18.0, -body_size.y + 7.0)
	# Sibling so the projectile keeps its own trajectory after the shot.
	shot.position += position
	get_parent().add_child(shot)
	Events.sfx_requested.emit(&"lob")
	_timer = 1.7
	_flash = false


func _draw_body() -> void:
	match role:
		Role.REGISTER:
			_draw_register()
		Role.TROLLEY:
			_draw_trolley()
		Role.ROCKING_HORSE:
			_draw_horse()
		Role.PLANTER:
			_draw_planter()


func _panel(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, INK, false, 3.0)


func _eyes(y: float, spread: float) -> void:
	for x in [-spread, spread]:
		draw_circle(Vector2(x, y), 4.8, EYE)
		draw_circle(Vector2(x + _direction * 1.8, y + 0.4), 2.0, INK)


func _draw_register() -> void:
	_panel(Rect2(-25, -31, 50, 28), skin_color)
	_panel(Rect2(-19, -35, 38, 13), skin_color.lightened(0.14))
	_eyes(-29.0, 7.0)
	var vent := Color(0.98, 0.55, 0.25) if _flash else INK
	for i in range(-2, 3):
		draw_line(Vector2(i * 7, -18), Vector2(i * 7, -9), vent, 3.0, true)


func _draw_trolley() -> void:
	for x in [-15.0, 15.0]:
		var point := Vector2(x, -6)
		draw_circle(point, 6.4, INK)
		var spoke := Vector2.from_angle(_wheel_angle) * 3.8
		draw_line(point - spoke, point + spoke, Color(0.92, 0.71, 0.36), 2.0, true)
	_panel(Rect2(-20, -35, 40, 22), skin_color)
	_panel(Rect2(-16, -43, 32, 10), skin_color.lightened(0.2))
	_eyes(-28.0, 8.0)


func _draw_horse() -> void:
	draw_arc(Vector2(0, -18), 18.0, 0.36, PI - 0.36, 16, INK, 5.0, true)
	draw_line(Vector2(-8, -13), Vector2(-12, -4), skin_color, 5.0, true)
	draw_line(Vector2(8, -13), Vector2(12, -4), skin_color, 5.0, true)
	_panel(Rect2(-19, -28, 38, 15), skin_color)
	_panel(Rect2(_direction * 12.0 - 7.0, -41, 14, 16), skin_color.lightened(0.14))
	draw_circle(Vector2(_direction * 15.0, -35), 3.0, EYE)
	draw_circle(Vector2(_direction * 16.0, -35), 1.6, INK)


func _draw_planter() -> void:
	var foliage := Color(0.66, 0.87, 0.38) if _flash else Color(0.36, 0.66, 0.35)
	for tip in [Vector2(-16, -45), Vector2(0, -48), Vector2(16, -43)]:
		draw_line(Vector2(0, -28), tip, INK, 9.0, true)
		draw_line(Vector2(0, -29), tip, foliage, 5.0, true)
	_panel(Rect2(-19, -31, 38, 10), skin_color.lightened(0.18))
	_panel(Rect2(-15, -22, 30, 20), skin_color)
	_eyes(-14.0, 7.0)
