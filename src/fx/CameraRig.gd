class_name CameraRig
extends Camera2D
## Player camera: engine smoothing + facing lookahead + vertical deadzone,
## screenshake (Events-driven), and boss-arena lock. Lives as a child of
## the Player; zones set world limits via set_zone_limits().

const LOOKAHEAD := 90.0
const LOOKAHEAD_SPEED := 3.5
const SHAKE_MAX := 8.0

var _zone_limits := Rect2(-100000, -100000, 200000, 200000)
var _shake_strength := 0.0
var _shake_left := 0.0
var _look_x := 0.0


func _ready() -> void:
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	drag_vertical_enabled = true
	drag_top_margin = 0.12
	drag_bottom_margin = 0.18
	Events.screenshake_requested.connect(_on_shake)
	_apply_limits(_zone_limits)


func set_zone_limits(rect: Rect2) -> void:
	_zone_limits = rect
	_apply_limits(rect)
	reset_smoothing()


func lock_to(rect: Rect2) -> void:
	_apply_limits(rect)


func unlock() -> void:
	_apply_limits(_zone_limits)


func _apply_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func set_facing(facing: float) -> void:
	_look_x = facing * LOOKAHEAD


func _process(delta: float) -> void:
	offset.x = lerpf(offset.x, _look_x, LOOKAHEAD_SPEED * delta)
	if _shake_left > 0.0:
		_shake_left -= delta
		var s: float = minf(_shake_strength, SHAKE_MAX) * (_shake_left / 0.3)
		offset.y = randf_range(-s, s)
		offset.x += randf_range(-s, s)
	else:
		offset.y = lerpf(offset.y, 0.0, 10.0 * delta)


func _on_shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_left = maxf(_shake_left, duration)
