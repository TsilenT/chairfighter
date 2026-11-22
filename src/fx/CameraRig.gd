class_name CameraRig
extends Camera2D
## Player camera: engine smoothing + facing lookahead + vertical deadzone,
## screenshake (Events-driven), and boss-arena lock. Lives as a child of
## the Player; zones set world limits via set_zone_limits().

const LOOKAHEAD := 90.0
const LOOKAHEAD_SPEED := 3.5
const SHAKE_MAX := 8.0
const BOSS_FLOOR_RATIO := 0.8
## The uppermost lower touch button starts 240 logical pixels from the bottom.
const TOUCH_FLOOR_CLEARANCE := 264.0

var _zone_limits := Rect2(-100000, -100000, 200000, 200000)
var _arena_limits := Rect2()
var _arena_floor_y := 0.0
var _arena_locked := false
var _shake_strength := 0.0
var _shake_left := 0.0
var _shake_duration := 0.0
var _look_current := 0.0
var _look_x := 0.0
var _release_offset := Vector2.ZERO


func _ready() -> void:
	make_current()
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	drag_vertical_enabled = true
	drag_top_margin = 0.12
	drag_bottom_margin = 0.18
	Events.screenshake_requested.connect(_on_shake)
	get_viewport().size_changed.connect(_refresh_limits)
	_apply_limits(_zone_limits)


func set_zone_limits(rect: Rect2) -> void:
	_zone_limits = rect
	_arena_locked = false
	_release_offset = Vector2.ZERO
	_refresh_limits()
	reset_smoothing()


func lock_to(rect: Rect2, floor_y: float) -> void:
	_arena_limits = rect
	_arena_floor_y = floor_y
	_arena_locked = true
	_look_current = 0.0
	_release_offset = Vector2.ZERO
	offset = Vector2.ZERO
	_refresh_limits()


func unlock() -> void:
	if not _arena_locked:
		return
	var previous_center := get_screen_center_position()
	_arena_locked = false
	_refresh_limits()
	var smoothing := position_smoothing_enabled
	position_smoothing_enabled = false
	force_update_scroll()
	# The clamped view and Camera2D's internal follow target can differ.
	# Ease out that difference so releasing the arena does not snap the view.
	_release_offset = previous_center - get_screen_center_position()
	offset += _release_offset
	force_update_scroll()
	position_smoothing_enabled = smoothing
	reset_smoothing()


func _refresh_limits() -> void:
	if not _arena_locked:
		_apply_limits(_zone_limits)
		return
	var view := get_viewport_rect().size
	var floor_screen_y := view.y * BOSS_FLOOR_RATIO
	if GameState.touch_controls:
		floor_screen_y = minf(floor_screen_y, view.y - TOUCH_FLOOR_CLEARANCE)
	# A viewport-height vertical limit holds the floor steady through jumps.
	# Arena rectangles describe combat space, whose bottom is often the floor.
	var world_view := view / zoom
	var top := _arena_floor_y - floor_screen_y / zoom.y
	var width := maxf(_arena_limits.size.x, world_view.x)
	var left := _arena_limits.get_center().x - width * 0.5
	_apply_limits(Rect2(left, top, width, world_view.y))


func _apply_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)


func set_facing(facing: float) -> void:
	_look_x = facing * LOOKAHEAD


func _process(delta: float) -> void:
	var look_target := 0.0 if _arena_locked else _look_x
	_look_current = lerpf(_look_current, look_target, 1.0 - exp(-LOOKAHEAD_SPEED * delta))
	_release_offset *= exp(-position_smoothing_speed * delta)
	var shake := Vector2.ZERO
	if GameState.camera_shake and _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var strength := minf(_shake_strength, SHAKE_MAX) * pow(_shake_left / _shake_duration, 2.0)
		var clock := float(Time.get_ticks_msec())
		shake = Vector2(sin(clock * 0.057), cos(clock * 0.071)) * strength
	offset = Vector2(_look_current, 0.0) + _release_offset + shake


func _on_shake(strength: float, duration: float) -> void:
	if not GameState.camera_shake or duration <= 0.0:
		return
	_shake_strength = strength
	_shake_left = duration
	_shake_duration = duration
