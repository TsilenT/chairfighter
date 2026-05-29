## Player - Basic Chair controller-first platformer controller with chair form switching, health, and melee combat.
##
## Handles input (gamepad first, keyboard fallback), platformer physics with
## coyote time, jump buffering, variable jump height, acceleration/deceleration,
## attached Camera2D follow, health, and a melee hitbox for attacking
## enemies. Delegates movement values and visuals to the active ChairForm
## via GameState.
##
## Attack flow:
##   Input.just_pressed("attack") → _perform_attack() → activate Hitbox (deals damage)
##   Hitbox overlaps Hurtbox on enemy → Hurtbox emits hitbox_entered → Enemy takes damage
##
## Damage flow:
##   Enemy hitbox overlaps Player Hurtbox → Hurtbox emits hitbox_entered → Player._health.take_damage()
##
## Layer/mask convention (Godot 4 bit flags):
##  - Bit 0 (1)    = collision world
##  - Bit 4 (16)   = hitboxes (melee attacks)    — Player's hitbox sits here
##  - Bit 3 (8)    = hurtboxes (take damage)      — Player & enemy hurtboxes sit here
##  - Bit 1 (2)    = enemies (player hits bodies)

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

## Health
@export_group("Health")
@export var max_health := 10.0

## Debounce cooldown for form switching (seconds).
const FORM_SWITCH_COOLDOWN := 0.15

## Debounce cooldown for melee attacks (seconds).
const ATTACK_COOLDOWN := 0.3


## Animation state for attack lean.
var _attack_extension: float = 0.0

## Direction the player is facing (-1 left, 1 right).
var _facing_right: float = 1.0

## Active form for movement/visual delegation.
var _active_form: ChairForm = null

# Internal timers
var _coyote_duration := 0.0
var _jump_buffer_duration := 0.0
var _ground_vel_zeroed := false
var _form_change_cooldown_remaining: float = 0.0

# Component references
var _health: Health
var _hitbox: Hitbox
var _hurtbox: Hurtbox
var _camera: Camera2D

# Debug
var _has_taken_damage: bool = false

@onready var _chair_body: ColorRect = $ChairBody


# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

func is_jumping() -> bool:
	return not is_on_floor() and velocity.y < 0.0


func is_on_ground() -> bool:
	return is_on_floor()


func is_alive() -> bool:
	return _health != null and _health.is_alive()


func get_camera() -> Camera2D:
	return _camera


# ──────────────────────────────────────────────
#  Initialization & form
# ──────────────────────────────────────────────

func _ready() -> void:
	_camera = find_child("Camera2D") as Camera2D
	if _camera != null:
		_camera.make_current()
		_camera.position = Vector2.ZERO

	# Initialize components
	_setup_hitbox()
	_setup_health()
	_setup_hurtbox()

	# Load form from GameState
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


# ──────────────────────────────────────────────
#  Hitbox + Health + Hurtbox setup
# ──────────────────────────────────────────────

func _setup_hitbox() -> void:
	"""Create a Hitbox component for melee combat."""
	_hitbox = Hitbox.new()
	_hitbox.name = "MeleeHitbox"

	# Apply properties
	_hitbox.damage = 2.0
	_hitbox.hit_direction = Vector2.RIGHT
	_hitbox.active_duration = 0.15

	add_child(_hitbox)
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(36.0, 36.0)
	hit_shape.shape = hit_rect
	hit_shape.position = Vector2(34.0, -32.0)
	_hitbox.add_child(hit_shape)


func _setup_hurtbox() -> void:
	"""Create a Hurtbox for the player to receive damage from enemies."""
	_hurtbox = Hurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.hitbox_entered.connect(_on_hurtbox_hit)
	add_child(_hurtbox)
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(44.0, 60.0)
	hurt_shape.shape = hurt_rect
	hurt_shape.position = Vector2(0.0, -32.0)
	_hurtbox.add_child(hurt_shape)


func _setup_health() -> void:
	"""Create a Health component with exported max_health."""
	_health = Health.new()
	_health.max_health = max_health

	# Connect to GameState for HUD updates before add_child() triggers _ready().
	_health.health_changed.connect(func(current: float, max_hp: float) -> void:
		GameState.update_player_health(current, max_hp)
	)
	_health.died.connect(func() -> void:
		print("[Player] Player died!")
		_has_taken_damage = true
		_chair_body.color = Color(0.3, 0.0, 0.0, 0.5)
	)
	add_child(_health)


func _on_hurtbox_hit(hitbox) -> void:
	"""Handle incoming hitbox damage from enemies."""
	if not _health:
		return
	if not is_alive():
		return
	if not (hitbox is Hitbox):
		return
	var damage_amount = hitbox.damage
	var kb = -hitbox.hit_direction.normalized()
	print("[Player] Took %d damage from hitbox!" % damage_amount)
	_health.take_damage(damage_amount, kb)


# ──────────────────────────────────────────────
#  Form switching
# ──────────────────────────────────────────────

func change_form(target_name: String) -> bool:
	"""Switch the active form. Returns true on success."""
	if not GameState.is_form_unlocked(target_name):
		printerr("[Player] Locked form: %s" % target_name)
		return false

	if GameState.current_form == target_name:
		return true  # Already active

	var prev_form = _active_form

	# Switch in GameState first
	var success = GameState.set_current_form(target_name)
	if not success:
		return false

	# Deactivate old
	if prev_form != null:
		prev_form.on_deactivate(GameState.get_current_form_def())

	# Activate new
	var new_form = GameState.get_current_form_def()
	_apply_current_form()
	if new_form != null:
		new_form.on_activate(prev_form)

	print("[Player] Switched to form: %s" % target_name)
	return true


func _cycle_form(direction: int) -> void:
	"""Cycle forms by direction (+1 = next, -1 = prev). Skips locked."""
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


# ──────────────────────────────────────────────
#  Physics step
# ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Clamp delta
	delta = min(delta, 1.0 / 30.0)

	# Handle timers
	_handle_coyote(delta)
	_handle_jump_buffer(delta)
	_handle_attack(delta)
	_handle_damage_reaction(delta)
	_count_jump_press()

	# Always apply gravity
	velocity.y += gravity * delta * _get_gravity_multiplier()

	# Horizontal
	var dir = _get_move_direction()
	if dir != 0.0:
		_move_horizontal(dir, delta)
		_flip_sprite(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)

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


# ──────────────────────────────────────────────
#  Input / mechanics
# ──────────────────────────────────────────────

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
	"""Keep buffered jump presses alive."""
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


# ──────────────────────────────────────────────
#  Movement helpers
# ──────────────────────────────────────────────

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
		_facing_right = sign(dir)
		scale.x = abs(scale.x) * sign(dir)


# ──────────────────────────────────────────────
#  Combat / Attack handling
# ──────────────────────────────────────────────

func _handle_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_perform_attack()

	if _attack_extension > 0.0:
		_attack_extension -= delta * 5.0
		if _attack_extension < 0.0:
			_attack_extension = 0.0


func _perform_attack() -> void:
	if not _hitbox:
		printerr("[Player] Hitbox not initialized!")
		return

	_hitbox.hit_direction = Vector2.RIGHT * _facing_right
	if not _hitbox.activate():
		return
	_attack_extension = 1.0

	var attack_direction := "right" if _facing_right > 0 else "left"
	print("[Player] Attack! Direction: %s" % attack_direction)


func _handle_damage_reaction(delta: float) -> void:
	if _health and _health.knockback_force != Vector2.ZERO:
		velocity.x = _health.knockback_force.x
		_health.knockback_force = Vector2.ZERO
