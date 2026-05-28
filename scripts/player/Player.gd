## Player - Basic Chair controller-first platformer controller with chair form switching.
##
## Handles input (gamepad first, keyboard fallback), platformer physics with
## coyote time, jump buffering, variable jump height, acceleration/deceleration,
## and attached Camera2D follow. Delegates movement values and visuals to the
## active ChairForm via GameState.

extends CharacterBody2D

## Movement tuning constants - overridden by active form at switch time.
@export_group("Movement")
@export var max_speed := 280.0
@export var acceleration := 1800.0
@export var deceleration := 2000.0
@export var air_control := 0.5
@export var gravity := 980.0

## Jump tuning constants
@export_group("Jump")
@export var jump_velocity := -520.0
@export var gravity_scale := 3.5
@export var gravity_extra := 3.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.15

## Camera
@export_group("Camera")
@export var cam_smoothing := 8.0
@export var zoom_base := Vector2.ONE

## Debounce cooldown for form switching (seconds).
const FORM_SWITCH_COOLDOWN := 0.15

## Form - active form for movement/visual delegation.
var _active_form: ChairForm = null

# Internal state
var _coyote_duration := 0.0
var _jump_buffer_duration := 0.0
var _ground_vel_zeroed := false
var _camera: Camera2D
var _form_change_cooldown_remaining: float = 0.0

@onready var _chair_body: ColorRect = $ChairBody


# ───────────────────────────────
#  Public API
# ───────────────────────────────

func is_jumping() -> bool:
	return not is_on_floor() and velocity.y < 0.0


func is_on_ground() -> bool:
	return is_on_floor()


func get_camera() -> Camera2D:
	return _camera


# ───────────────────────────────
#  Initialization & form
# ───────────────────────────────

func _ready() -> void:
	_camera = find_child("Camera2D") as Camera2D
	if _camera != null:
		_camera.make_current()
		_camera.position = Vector2.ZERO
	
	# Load form from GameState (should be BasicChair at startup)
	_apply_current_form()


func _apply_current_form() -> void:
	"""Load form vars and set internal reference."""
	var form_def = GameState.get_current_form_def()
	if form_def:
		_active_form = form_def
		max_speed = form_def.max_speed
		acceleration = form_def.acceleration
		deceleration = form_def.deceleration
		air_control = form_def.air_control
		jump_velocity = form_def.jump_velocity
		gravity_scale = form_def.gravity_scale
		_update_placeholder_color()
	else:
		printerr("[Player] No active form in GameState!")
		_active_form = null


func _update_placeholder_color() -> void:
	"""Apply active form's body_color to the ColorRect player visual."""
	if _chair_body != null and _active_form != null:
		_chair_body.color = _active_form.body_color


# ───────────────────────────────
#  Form switching
# ───────────────────────────────

func change_form(target_name: String) -> bool:
	"""Switch the active form. Returns true on success."""
	if not GameState.is_form_unlocked(target_name):
		printerr("[Player] Locked form: %s" % target_name)
		return false
	
	if GameState.current_form == target_name:
		return true  # Already active
	
	var prev_form = _active_form
	
	# Switch in GameState first (so current_form is updated)
	var success = GameState.set_current_form(target_name)
	if not success:
		return false
	
	# Deactivate old (now GameState.current_form = new, so old can see new)
	if prev_form != null:
		prev_form.on_deactivate(GameState.get_current_form_def())
	
	# Activate new
	var new_form = GameState.get_current_form_def()
	_apply_current_form()
	if new_form != null:
		new_form.on_activate(prev_form)
	
	print("[Player] Switched to: %s" % target_name)
	return true


func _cycle_form(direction: int) -> void:
	"""Cycle forms by given direction (+1 = next, -1 = prev). Skips locked."""
	var current_idx = GameState.get_unlocked_form_index()
	if current_idx < 0:
		return
	
	var i = current_idx
	var iterations = GameState.form_order.size()
	while iterations > 0:
		i = (i + direction + GameState.form_order.size()) % GameState.form_order.size()
		if i == current_idx:
			return  # Wrapped, no other unlocked form
		var candidate = GameState.form_order[i]
		if candidate in GameState.unlocked_forms:
			change_form(candidate)
			return
		iterations -= 1


func _handle_form_cycle(delta: float) -> void:
	"""Handle transform_next/prev input with debounce cooldown."""
	# Check cooldown first
	if _form_change_cooldown_remaining > 0.0:
		_form_change_cooldown_remaining -= delta
		return
	
	if Input.is_action_just_pressed("transform_next"):
		_cycle_form(1)
		_form_change_cooldown_remaining = FORM_SWITCH_COOLDOWN
		return
	
	if Input.is_action_just_pressed("transform_prev"):
		_cycle_form(-1)
		_form_change_cooldown_remaining = FORM_SWITCH_COOLDOWN


# ───────────────────────────────
#  Physics step
# ───────────────────────────────

func _physics_process(delta: float) -> void:
	# Clamp delta
	delta = min(delta, 1.0 / 30.0)
	
	# Handle timers
	_handle_coyote(delta)
	_handle_jump_buffer(delta)
	_count_jump_press()
	
	# Always apply gravity
	velocity.y += gravity * delta * _get_gravity_multiplier()
	
	# Horizontal
	var dir = _get_move_direction()
	if dir != 0.0:
		_move_horizontal(dir, delta)
		_flip_sprite(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	
	# Jump execution
	if _jump_buffer_duration > 0.0:
		_jump_buffer_duration -= delta
		if is_on_floor() or _coyote_duration > 0.0:
			_execute_jump()
			_jump_buffer_duration = 0.0
	
	# Form cycle
	_handle_form_cycle(delta)
	
	# Move & slide
	move_and_slide()
	
	# Auto-zero velocity on ground
	if is_on_floor() and not _ground_vel_zeroed:
		if abs(velocity.x) < acceleration * delta * 0.5:
			velocity.x = 0.0
			_ground_vel_zeroed = true


# ───────────────────────────────
#  Input / mechanics
# ───────────────────────────────

func _get_move_direction() -> float:
	"""Get combined keyboard/controller move direction with deadzone filtering."""
	var dir = Input.get_axis("move_left", "move_right")
	# Controller sticks are already deadzone-filtered
	if Input.get_connected_joypads().size() > 0:
		var stick = Input.get_axis("move_left", "move_right")
		if stick != 0.0:
			return stick
	return dir


func _count_jump_press() -> void:
	"""Buffer jump on just-pressed input for coyote time compatibility."""
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_duration = max(_jump_buffer_duration, jump_buffer_time)


func _handle_coyote(delta: float) -> void:
	if is_on_floor():
		_coyote_duration = coyote_time
	else:
		_coyote_duration -= delta


func _handle_jump_buffer(delta: float) -> void:
	"""Keep buffered jump presses alive even if player releases before landing."""
	pass


func _execute_jump() -> void:
	"""Execute jump using form-specific jump velocity."""
	velocity.y = jump_velocity * _get_jump_multiplier()
	_coyote_duration = 0.0


func _get_jump_multiplier() -> float:
	if not Input.is_action_pressed("jump"):
		return 0.5  # Variable height: released early
	return 1.0


func _get_gravity_multiplier() -> float:
	if Input.is_action_pressed("jump"):
		return gravity_scale
	return gravity_scale + gravity_extra


func _can_perform_jump() -> bool:
	return is_on_floor() or _coyote_duration > 0.0


# ───────────────────────────────
#  Movement helpers
# ───────────────────────────────

func _move_horizontal(dir: float, delta: float) -> void:
	var accel = acceleration
	if not is_on_floor():
		accel *= air_control
	var target_vel = dir * max_speed
	if sign(velocity.x) != sign(dir):
		accel *= deceleration / acceleration
	var prev_vel = velocity.x
	velocity.x = move_toward(prev_vel, target_vel, accel * delta)
	if abs(velocity.x - target_vel) < 1.0:
		velocity.x = target_vel


func _flip_sprite(dir: float) -> void:
	if dir != 0.0:
		scale.x = abs(scale.x) * sign(dir)


func _handle_camera(delta: float) -> void:
	if _camera != null:
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = cam_smoothing
