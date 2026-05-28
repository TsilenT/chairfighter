## Player — Basic Chair controller-first platformer controller.
##
## Handles input (gamepad first, keyboard fallback), platformer physics with
## coyote time, jump buffering, variable jump height, acceleration/deceleration,
## and attached Camera2D follow.

extends CharacterBody2D

## Movement tuning constants
@export_group("Movement")
@export	var	max_speed := 280.0
@export	var	acceleration := 1800.0
@export	var	deceleration := 2000.0
@export	var	air_control := 0.5  # multiplier applied to accel/decel in air
@export	var	gravity := 980.0

## Jump tuning constants
@export_group("Jump")
@export	var	jump_velocity := -520.0
@export	var	gravity_scale := 3.5
@export	var	gravity_extra := 3.0  # extra gravity multiplier when releasing jump early
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.15

## Camera
@export_group("Camera")
@export var cam_smoothing := 8.0
@export var zoom_base := Vector2.ONE

# Internal state
var _coyote_duration := 0.0
var _jump_buffer_duration := 0.0
var _ground_vel_zeroed := false
var _camera: Camera2D


# ─────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────

func is_jumping() -> bool:
	return not is_on_floor() and velocity.y < 0.0


func is_on_ground() -> bool:
	return is_on_floor()


func get_camera() -> Camera2D:
	return _camera


# ─────────────────────────────────────────
#  Initialization
# ─────────────────────────────────────────

func _ready() -> void:
	_camera = find_child("Camera2D") as Camera2D
	if _camera != null:
		_camera.make_current()
		_camera.position = Vector2.ZERO


# ─────────────────────────────────────────
#  Physics step - core movement logic
# ─────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Clamp delta to avoid huge jumps on frame drops without zeroing normal 60 FPS ticks.
	delta = min(delta, 1.0 / 30.0)

	# Track coyote time and jump buffer timers
	_handle_coyote(delta)
	_handle_jump_buffer(delta)

	# Count just-pressed jump for buffer activation
	_count_jump_press()

	# Always apply gravity
	velocity.y += gravity * delta * _get_gravity_multiplier()

	# Horizontal movement
	var dir: float = _get_move_direction()
	if dir != 0.0:
		_move_horizontal(dir, delta)
		_flip_sprite(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	# Jump execution (from buffer)
	if _jump_buffer_duration > 0.0:
		_jump_buffer_duration -= delta
		if is_on_floor() or _coyote_duration > 0.0:
			_execute_jump()
			_jump_buffer_duration = 0.0

	# Move & slide
	move_and_slide()

	# Zero horizontal velocity when it naturally dies out on ground
	if is_on_floor() and not _ground_vel_zeroed:
		if abs(velocity.x) < acceleration * delta * 0.5:
			velocity.x = 0.0
			_ground_vel_zeroed = true

	# Camera follow is handled by the active Camera2D child.


# ─────────────────────────────────────────
#  Input processing
# ─────────────────────────────────────────

func _get_move_direction() -> float:
	var dir: float = Input.get_axis("move_left", "move_right")
	# Prefer controller stick if any connected
	if Input.get_connected_joypads().size() > 0:
		var stick: float = Input.get_axis("move_left", "move_right")
		if stick != 0.0:  # already deadzone-filtered by Godot
			return stick
	return dir


func _count_jump_press() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_duration = max(_jump_buffer_duration, jump_buffer_time)


func _handle_coyote(delta: float) -> void:
	if is_on_floor():
		_coyote_duration = coyote_time
	else:
		_coyote_duration -= delta


func _handle_jump_buffer(delta: float) -> void:
	# Keep buffered jump presses alive even if the player releases before landing.
	# Variable jump height is handled separately by extra gravity after release.
	pass


func _get_jump_multiplier() -> float:
	if not Input.is_action_pressed("jump"):
		return 0.5  # variable height: released early
	return 1.0


func _get_gravity_multiplier() -> float:
	if Input.is_action_pressed("jump"):
		return gravity_scale
	return gravity_scale + gravity_extra  # extra gravity when released early


func _can_perform_jump() -> bool:
	return is_on_floor() or _coyote_duration > 0.0


func _execute_jump() -> void:
	velocity.y = jump_velocity * _get_jump_multiplier()
	_coyote_duration = 0.0


# ─────────────────────────────────────────
#  Movement helpers
# ─────────────────────────────────────────

func _move_horizontal(dir: float, delta: float) -> void:
	var accel: float = acceleration
	if not is_on_floor():
		accel *= air_control
	var target_vel: float = dir * max_speed
	# Faster deceleration when reversing direction
	if sign(velocity.x) != sign(dir):
		accel *= deceleration / acceleration  # ~1.56x faster decel
	var prev_vel: float = velocity.x
	velocity.x = move_toward(prev_vel, target_vel, accel * delta)
	# Snap when very close.
	if abs(velocity.x - target_vel) < 1.0:
		velocity.x = target_vel


func _flip_sprite(dir: float) -> void:
	# Placeholder art uses ColorRect nodes, so mirror the root scale for now.
	if dir != 0.0:
		scale.x = abs(scale.x) * sign(dir)


func _handle_camera(delta: float) -> void:
	if _camera != null:
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = cam_smoothing
