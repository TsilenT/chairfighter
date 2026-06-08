## Player - Basic Chair controller-first platformer controller with chair form
## switching, health, melee combat, and extendable-arm grapple (Armchair only).
##
## Handles input (gamepad first, keyboard fallback), platformer physics with
## coyote time, jump buffering, variable jump height, acceleration/deceleration,
## attached Camera2D follow, health, melee hitbox, and grapple. Delegates
## movement values and visuals to the active ChairForm via GameState.
##
## Attack flow:
##   Input.just_pressed("attack") → _perform_attack() → activate Hitbox
##   Hitbox overlaps enemy Hurtbox → _on_hurtbox_hit() → enemy takes damage.
##
## Damage flow:
##   Enemy hitbox overlaps Player Hurtbox → Player takes damage.
##
## Grapple flow (Armchair only):
##   Input.is_action_just_pressed("special") → find nearest GrapplePoint in range
##   and direction → attach → continuously pull toward point.
##   Input.is_action_just_released("special") → detach → slight forward boost.
##
## Layer/mask convention (Godot 4 bit flags):
##  - Bit 0 (1)    = collision world
##  - Bit 4 (16)   = hitboxes (melee)     — Player hitbox sits here
##  - Bit 3 (8)    = hurtboxes (damage)    — Player & enemy hurtboxes sit here
##  - Bit 1 (2)    = enemies (player hits)

extends CharacterBody2D

const ChairFormType = preload("res://scripts/player/ChairForm.gd")
const ArmchairFormType = preload("res://scripts/player/forms/ArmchairForm.gd")
const GrapplePointType = preload("res://scripts/world/GrapplePoint.gd")
const HealthType = preload("res://scripts/components/Health.gd")
const HitboxType = preload("res://scripts/components/Hitbox.gd")
const HurtboxType = preload("res://scripts/components/Hurtbox.gd")

## ────────
#  Movement tuning — overwritten by active form at switch time.
## ────────
@export_group("Movement")
@export var max_speed := 280.0
@export var acceleration := 1800.0
@export var deceleration := 2000.0
@export var air_control := 0.5
@export var gravity := 980.0

## ────────
#  Jump tuning
## ────────
@export_group("Jump")
@export var jump_velocity := -520.0
@export var gravity_scale := 3.5
@export var gravity_extra := 3.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.15

## ────────
#  Camera
## ────────
@export_group("Camera")
@export var cam_smoothing := 8.0
@export var zoom_base := Vector2.ONE

## ────────
#  Health
## ────────
@export_group("Health")
@export var max_health := 10.0

## ────────
#  Grapple tuning (Armchair)
## ────────
@export_group("Grapple")
@export var grapple_range := 300.0
@export var grapple_speed := 450.0
@export var grapple_slowdown_speed := 150.0


const FORM_SWITCH_COOLDOWN := 0.15
const ATTACK_COOLDOWN := 0.3

## ────────
#  Internal state
## ────────

## Animation lean for attack extension.
var _attack_extension: float = 0.0

## Grapple state machine.
var _is_grappling: bool = false
## Grapple point we're currently attached to (Object to avoid parse-time type resolution).
var _grapple_target: Object = null  # the point we're attached to
var _grapple_active: bool = false         # true while special is held & valid

## Direction the player is facing (-1 left, 1 right).
var _facing_right: float = 1.0

## Active form for movement/visual delegation.
var _active_form: ChairForm = null

## Internal timers.
var _coyote_duration: float = 0.0
var _jump_buffer_duration: float = 0.0
var _ground_vel_zeroed: bool = false
var _form_change_cooldown: float = 0.0

## Saved spawn position for respawn.
var _spawn_position: Vector2 = Vector2.ZERO

## Whether the player is currently dead and waiting for restart input.
var _is_dead: bool = false

## Signal emitted when the player dies.
signal player_died

## Component references.
var _health: Health
var _hitbox: Hitbox
var _hurtbox: Hurtbox
var _camera: Camera2D
var _hitbox_shape: CollisionShape2D
var _attack_flash: ColorRect

## Debug flag (flip on damage).
var _has_taken_damage: bool = false

## Visual nodes.
@onready var _chair_body: ColorRect = $ChairBody
@onready var _grapple_rope: Line2D = $GrappleRope

## Visual overlay shown when dead.
var _death_overlay: ColorRect = null

# ────────
#  Public API
# ────────

func is_jumping() -> bool:
	return not is_on_floor() and velocity.y < 0.0


func is_on_ground() -> bool:
	return is_on_floor()


func is_alive() -> bool:
	return _health != null and _health.is_alive()


func is_grappling() -> bool:
	return _is_grappling


func get_camera() -> Camera2D:
	return _camera


# ────────
#  Initialization & form
# ────────

func _ready() -> void:
	add_to_group("player")
	_spawn_position = position
	# Connect to restart signal from GameState.
	GameState.game_restart.connect(func() -> void:
		if not _is_dead:
			print("[Player] Restart called but player is alive — ignoring.")
			return
		print("[Player] Game restart received. Respawning.")
		respawn()
	)

	# Set up camera.
	_camera = find_child("Camera2D") as Camera2D
	if _camera:
		_camera.make_current()
		_camera.position = Vector2.ZERO

	# Pivot the chair visual around its own center so left/right flips look
	# centered on the body instead of swinging around the top-left corner.
	if _chair_body:
		_chair_body.pivot_offset = _chair_body.size * 0.5

	# Set up components.
	_setup_hitbox()
	_setup_health()
	_setup_hurtbox()
	_setup_grapple_rope()

	# Load the current form from GameState.
	_apply_current_form()


func _setup_grapple_rope() -> void:
	"""Create the golden rope visual for grapple."""
	if not _grapple_rope:
		return
	_grapple_rope.visible = false
	_grapple_rope.width = 3.0
	_grapple_rope.default_color = Color(0.9, 0.7, 0.1, 0.8)


func _apply_current_form() -> void:
	"""Load movement vars and reference from GameState."""
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
	if _chair_body and _active_form:
		_chair_body.color = _active_form.body_color


# ────────
#  Health + Hitbox + Hurtbox setup
# ────────

func _setup_hitbox() -> void:
	_hitbox = Hitbox.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.damage = 2.0
	_hitbox.hit_direction = Vector2.RIGHT
	_hitbox.active_duration = 0.15
	add_child(_hitbox)
	_hitbox_shape = CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(48.0, 34.0)
	_hitbox_shape.shape = hit_rect
	_hitbox_shape.position = Vector2(52.0, -34.0)
	_hitbox.add_child(_hitbox_shape)

	_attack_flash = ColorRect.new()
	_attack_flash.name = "AttackFlash"
	_attack_flash.size = Vector2(48.0, 22.0)
	_attack_flash.position = Vector2(28.0, -46.0)
	_attack_flash.color = Color(1.0, 0.9, 0.25, 0.75)
	_attack_flash.visible = false
	_attack_flash.z_index = 5
	add_child(_attack_flash)


func _setup_hurtbox() -> void:
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
	_health = Health.new()
	_health.max_health = max_health
	_health.health_changed.connect(func(current: float, max_hp: float) -> void:
		GameState.update_player_health(current, max_hp)
	)
	_health.died.connect(_on_player_died)
	add_child(_health)


func _on_hurtbox_hit(hitbox: Hitbox) -> void:
	if not _health or not is_alive() or not hitbox:
		return
	var dmg = hitbox.damage
	var kb = -hitbox.hit_direction.normalized()
	_health.take_damage(dmg, kb)


# ────────
#  Death & respawn
# ────────

func _on_player_died() -> void:
	print("[Player] Player died!")
	_has_taken_damage = true
	_chair_body.color = Color(0.3, 0.0, 0.0, 0.5)
	_is_dead = true
	velocity = Vector2.ZERO
	player_died.emit()
	GameState.player_died.emit()


func respawn() -> void:
	"""Respawn player: fully restore health and reset position."""
	print("[Player] Player respawning!")
	_has_taken_damage = false
	_is_dead = false
	_chair_body.color = Color(0.6, 0.5, 0.3, 1)
	position = _spawn_position
	velocity = Vector2.ZERO
	if _health:
		_health.max_health = max_health
		_health.current_hp = max_health
		_health.health_changed.emit(max_health, max_health)
	if GameState.get_current_form_def():
		GameState.update_player_health(max_health, max_health)


# ────────
#  Grapple logic
# ────────

var _closest_grapple_dist: float = INF


func _update_grapple_state(delta: float) -> void:
	"""Handle grapple input, detection, and physics."""
	if not _active_form or not _active_form is ArmchairForm:
		_release_grapple()
		return

	# Always draw the rope when holding special (even if no point targetted).
	if Input.is_action_pressed("special"):
		if _grapple_rope and not _grapple_rope.visible:
			_grapple_rope.visible = true

	# Find closest grapple point in range and direction.
	_update_grapple_scan()

	var want_start = Input.is_action_just_pressed("special")
	var want_release = Input.is_action_just_released("special")

	if want_release:
		_release_grapple()
	elif want_start and _closest_grapple_dist <= grapple_range:
		_start_grapple()


func _update_grapple_scan() -> void:
	"""Scan scene for closest GrapplePoint in range AND direction."""
	_closest_grapple_dist = INF
	var candidate: GrapplePoint = null
	var scan_radius = grapple_range

	# Walk _all_ GrapplePoint nodes in the scene.
	for gp in get_tree().get_nodes_in_group("grapple_points"):
		if not (gp is GrapplePoint):
			continue
		var dist = global_position.distance_to(gp.global_position)
		if dist > scan_radius:
			continue
		# Only grapple things in front of us (dot test with facing direction).
		var to_point = gp.global_position - global_position
		var fwd = Vector2.RIGHT * _facing_right
		if to_point.dot(fwd) < 0:
			continue
		if dist < _closest_grapple_dist:
			_closest_grapple_dist = dist
			candidate = gp

	_grapple_target = candidate


func _start_grapple() -> void:
	if not _grapple_target or _closest_grapple_dist > grapple_range:
		print("[Player] Can't grapple — no valid target.")
		return
	_is_grappling = true
	_grapple_active = true
	print("[Player] Grapple started — pulling toward %s at dist %.0f" % [
		_grapple_target.global_position,
		_closest_grapple_dist,
	])


func _release_grapple() -> void:
	if not _is_grappling:
		return
	print("[Player] Grapple released.")
	_is_grappling = false
	_grapple_active = false
	_grapple_target = null
	if _grapple_rope:
		_grapple_rope.visible = false
	# Give a tiny forward kick on release for better feel.
	velocity.x += _facing_right * grapple_slowdown_speed * 0.3


func _apply_grapple_pull(delta: float) -> void:
	"""While grapple is active, pull velocity toward the target."""
	if not _is_grappling:
		return
	if not _grapple_target:
		_release_grapple()
		return

	var dist = global_position.distance_to(_grapple_target.global_position)

	# Stop if we've reached the point.
	if dist < 5.0:
		_release_grapple()
		return

	# Interpolate speed: fast when far, slow when close.
	var t = clampf((_closest_grapple_dist - dist) / max(1.0, grapple_range - 5.0), 0.0, 1.0)
	var speed = lerp(grapple_speed, grapple_slowdown_speed, t)

	var dir = (_grapple_target.global_position - global_position).normalized()
	velocity.x = dir.x * speed
	velocity.y = dir.y * speed  # also pull vertically toward point


func _draw_grapple_rope() -> void:
	if not _grapple_target or not _grapple_rope:
		return
	_grapple_rope.clear_points()
	_grapple_rope.add_point(Vector2.ZERO)
	_grapple_rope.add_point(_grapple_target.global_position - global_position)


# ────────
#  Form switching
# ────────

func change_form(target_name: String) -> bool:
	if not GameState.is_form_unlocked(target_name):
		printerr("[Player] Form locked: %s" % target_name)
		return false
	if GameState.current_form == target_name:
		return true

	var prev_form = _active_form
	if not GameState.set_current_form(target_name):
		return false

	if prev_form:
		prev_form.on_deactivate(GameState.get_current_form_def())

	var new_form = GameState.get_current_form_def()
	_apply_current_form()
	if new_form:
		new_form.on_activate(prev_form)

	print("[Player] Switched form to: %s" % target_name)
	return true


func _cycle_form(direction: int) -> void:
	var current_idx = GameState.get_unlocked_form_index()
	if current_idx < 0:
		return
	var i = current_idx
	var iterations = GameState.form_order.size()
	while iterations > 0:
		i = (i + direction + GameState.form_order.size()) % GameState.form_order.size()
		if i == current_idx:
			return
		var candidate = GameState.form_order[i]
		if candidate in GameState.unlocked_forms:
			change_form(candidate)
			return
		iterations -= 1


func _handle_form_cycle(delta: float) -> void:
	if _form_change_cooldown > 0.0:
		_form_change_cooldown -= delta
		return
	if Input.is_action_just_pressed("transform_next"):
		_cycle_form(1)
		_form_change_cooldown = FORM_SWITCH_COOLDOWN
		return
	if Input.is_action_just_pressed("transform_prev"):
		_cycle_form(-1)
		_form_change_cooldown = FORM_SWITCH_COOLDOWN


# ────────
#  Physics step
# ────────

func _physics_process(delta: float) -> void:
	delta = min(delta, 1.0 / 30.0)

	# ────────
	#  Death overlay & restart input
	# ────────
	_handle_death_overlay()
	if _is_dead and Input.is_action_just_pressed("restart"):
		print("[Player] Restart input detected — requesting game restart.")
		GameState.restart_game()
		return

	# Timers.
	_handle_coyote(delta)
	_handle_jump_buffer(delta)
	_handle_attack(delta)
	_handle_damage_reaction(delta)
	_count_jump_press()
	_handle_form_cycle(delta)

	# ─── Grapple update (form-gated) ───
	_update_grapple_state(delta)
	_apply_grapple_pull(delta)
	if _grapple_active:
		_draw_grapple_rope()
	else:
		if _grapple_rope:
			_grapple_rope.visible = false

	# Gravity.
	velocity.y += gravity * delta * _get_gravity_multiplier()

	# Horizontal movement.
	var dir = _get_move_direction()
	if dir != 0.0:
		_move_horizontal(dir, delta)
		_flip_sprite(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)

	# Jump buffer → execute.
	if _jump_buffer_duration > 0.0:
		_jump_buffer_duration -= delta
		if is_on_floor() or _coyote_duration > 0.0:
			_execute_jump()
			_jump_buffer_duration = 0.0

	# Move & slide.
	move_and_slide()

	# Auto-zero ground velocity.
	if is_on_floor() and not _ground_vel_zeroed:
		if abs(velocity.x) < acceleration * delta * 0.5:
			velocity.x = 0.0
			_ground_vel_zeroed = true


# ────────
#  Input & mechanics
# ────────

func _get_move_direction() -> float:
	var dir = Input.get_axis("move_left", "move_right")
	if Input.get_connected_joypads().size() > 0:
		var stick = Input.get_axis("move_left", "move_right")
		if stick != 0.0:
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
	# Buffer lives naturally; handled elsewhere.
	pass


func _execute_jump() -> void:
	velocity.y = jump_velocity * _get_jump_multiplier()
	_coyote_duration = 0.0


func _get_jump_multiplier() -> float:
	if not Input.is_action_pressed("jump"):
		return 0.5  # variable-height: released early = half speed
	return 1.0


func _get_gravity_multiplier() -> float:
	if Input.is_action_pressed("jump"):
		return gravity_scale
	return gravity_scale + gravity_extra


func _move_horizontal(dir: float, delta: float) -> void:
	var accel = acceleration
	if not is_on_floor():
		accel *= air_control
	var target = dir * max_speed
	if sign(velocity.x) != sign(dir):
		accel *= deceleration / acceleration
	var prev = velocity.x
	velocity.x = move_toward(prev, target, accel * delta)
	if abs(velocity.x - target) < 1.0:
		velocity.x = target


func _flip_sprite(dir: float) -> void:
	if dir != 0.0:
		_facing_right = sign(dir)
		# Flip only the visual, never the CharacterBody2D — negative scale on
		# the body corrupts its collision shapes (jitter / being shoved) and
		# mirrors the grapple rope. Attack direction uses _facing_right instead.
		if _chair_body:
			_chair_body.scale.x = sign(dir)


# ────────
#  Combat
# ────────

func _handle_attack(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_perform_attack()
	if _attack_extension > 0.0:
		_attack_extension -= delta * 5.0
		if _attack_extension < 0.0:
			_attack_extension = 0.0
	if _attack_flash:
		_attack_flash.visible = _attack_extension > 0.0


func _perform_attack() -> void:
	if not _hitbox:
		printerr("[Player] Hitbox not initialized!")
		return
	_hitbox.hit_direction = Vector2.RIGHT * _facing_right
	if _hitbox_shape:
		_hitbox_shape.position = Vector2(52.0 * _facing_right, -34.0)
	if _attack_flash:
		_attack_flash.position = Vector2(28.0 if _facing_right > 0 else -76.0, -46.0)
	if not _hitbox.activate():
		return
	_attack_extension = 1.0
	print("[Player] Attack! Direction: %s" % "right" if _facing_right > 0 else "left")


func _handle_damage_reaction(delta: float) -> void:
	if _health and _health.knockback_force != Vector2.ZERO:
		velocity.x = _health.knockback_force.x
		_health.knockback_force = Vector2.ZERO


# ────────
#  Death overlay
# ────────

func _handle_death_overlay() -> void:
	# Toggle the HUD death overlay based on the player's death state.
	if get_tree() == null:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud is CanvasLayer:
		return
	var overlay := hud.get_node_or_null("DeathOverlay")
	var text := hud.get_node_or_null("DeathText")
	if overlay:
		overlay.visible = _is_dead
	if text:
		text.visible = _is_dead
