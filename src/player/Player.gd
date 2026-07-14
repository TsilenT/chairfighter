class_name Player
extends CharacterBody2D
## The chair. One controller for all forms; per-form movement comes from
## FormDef resources, per-form verbs (grapple / dash / fold) dispatch on the
## active form id. Origin at the FEET. States: MOVE, DASH, GRAPPLE, HURT, DEAD.
##
## Collider heights: standing 56 · dashing 32 · folded 20. After a dash or an
## unfold request, the tall collider is only restored once headroom is clear,
## so tunnels/vents can be traversed even when the special state ends inside.

enum State { MOVE, DASH, GRAPPLE, HURT, DEAD }

const BODY_WIDTH := 44.0
const STAND_HEIGHT := 56.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.15
const JUMP_CUT := 0.4
const MAX_FALL_SPEED := 1300.0
const TRANSFORM_COOLDOWN := 0.15

const DASH_SPEED := 700.0
const DASH_TIME := 0.35
const DASH_COOLDOWN := 0.5
const DASH_HEIGHT := 32.0

const GRAPPLE_RANGE := 380.0
const GRAPPLE_SPEED := 900.0
const GRAPPLE_ARRIVE_DIST := 26.0
const GRAPPLE_KEEP := 0.55

const FOLD_HEIGHT := 20.0
const FOLD_SPEED := 140.0
const SPRING_HEIGHT := 230.0

const ROCK_CHARGE_MIN := 0.5
const ROCK_LAUNCH_HEIGHT := 260.0
const ROCK_CHARGE_SPEED := 60.0
const SLAM_FALL_SPEED := 900.0

const MAX_HEARTS := 5.0

var state: int = State.MOVE
var form: FormDef = null
var facing := 1.0
var folded := false

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_cut_done := true
var _spring_active := false
var _rock_charge := 0.0
var _launched := false
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _attack_cooldown := 0.0
var _hurt_left := 0.0
var _transform_cooldown := 0.0
var _was_on_floor := false
var _fall_peak_speed := 0.0
var _grapple_target: Node2D = null

var _health: Health
var _hitbox: Hitbox
var _slam_hitbox: Hitbox
var _hurtbox: Hurtbox

@onready var _collider: CollisionShape2D = $Collider
@onready var _visual: PlayerVisual = $Visual
@onready var _camera: CameraRig = $CameraRig
@onready var _rope: Line2D = $GrappleRope


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_build_components()
	Events.form_changed.connect(func(_id: StringName) -> void: _apply_form())
	Events.form_unlocked.connect(_on_form_unlocked)
	_apply_form()
	_health.changed.emit(_health.current, _health.max_health)


func _build_components() -> void:
	_health = Health.new()
	_health.max_health = MAX_HEARTS
	_health.invuln_time = 1.5
	_health.changed.connect(func(cur: float, maximum: float) -> void:
		Events.player_health_changed.emit(int(cur), int(maximum)))
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	add_child(_health)

	_hurtbox = Hurtbox.new()
	_hurtbox.faction = &"player"
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(BODY_WIDTH - 6.0, STAND_HEIGHT - 8.0)
	hurt_shape.shape = hurt_rect
	hurt_shape.position = Vector2(0, -(STAND_HEIGHT - 8.0) / 2.0)
	_hurtbox.add_child(hurt_shape)
	_hurtbox.hit_received.connect(_on_hit_received)
	add_child(_hurtbox)

	_hitbox = Hitbox.new()
	_hitbox.faction = &"player"
	var hit_shape := CollisionShape2D.new()
	hit_shape.shape = RectangleShape2D.new()
	_hitbox.add_child(hit_shape)
	add_child(_hitbox)

	# Rocking-slam shockwave: wide, low, at the feet.
	_slam_hitbox = Hitbox.new()
	_slam_hitbox.faction = &"player"
	_slam_hitbox.damage = 2.0
	_slam_hitbox.knockback_strength = 420.0
	var slam_shape := CollisionShape2D.new()
	var slam_rect := RectangleShape2D.new()
	slam_rect.size = Vector2(170.0, 26.0)
	slam_shape.shape = slam_rect
	slam_shape.position = Vector2(0, -10)
	_slam_hitbox.add_child(slam_shape)
	add_child(_slam_hitbox)


func _apply_form() -> void:
	var id := GameState.current_form
	var path := "res://src/forms/%s.tres" % id
	form = load(path)
	if form == null:
		push_error("[Player] Missing form resource: %s" % path)
		return
	if folded and id != &"folding":
		_set_folded(false)
		if folded:
			# No headroom to unfold (unlock fired inside a vent): refuse the
			# swap rather than strand a non-folding form at 20px tall.
			GameState.set_form(&"folding")
			return
	# Leaving the rocking form mid-charge must not carry the charge (which
	# would lock the new form's speed and fire a phantom launch on return).
	if _rock_charge != 0.0:
		_rock_charge = 0.0
		_visual.set_charge(0.0)
	_hitbox.damage = form.attack_damage
	var shape: RectangleShape2D = (_hitbox.get_child(0) as CollisionShape2D).shape
	shape.size = Vector2(form.attack_range, 36.0)
	_visual.set_form(form)
	# Never grow the collider into a ceiling (e.g. transforming right after a
	# dash ended inside a tunnel) — _restore_collider_when_clear() grows it
	# once there is headroom.
	var want_h := FOLD_HEIGHT if folded else STAND_HEIGHT
	var current_h := (_collider.shape as RectangleShape2D).size.y
	if want_h <= current_h or _headroom_clear(want_h):
		_set_collider_height(want_h)
	Events.sfx_requested.emit(&"transform")


func _on_form_unlocked(id: StringName) -> void:
	var def: FormDef = load("res://src/forms/%s.tres" % id)
	if def != null:
		Events.unlock_banner_requested.emit(id, def.display_name, def.unlock_blurb)


## Called by Game after placing us at a spawn point.
func on_spawned() -> void:
	velocity = Vector2.ZERO
	state = State.MOVE
	_release_grapple(false)
	_set_folded(false)
	_reset_transient_motion()
	_camera.reset_smoothing()


## Clear all one-shot motion flags so nothing leaks across respawn/zone load.
func _reset_transient_motion() -> void:
	_launched = false
	_spring_active = false
	_rock_charge = 0.0
	_fall_peak_speed = 0.0
	_was_on_floor = false
	if _visual != null:
		_visual.set_charge(0.0)


func revive() -> void:
	_health.reset_full()
	state = State.MOVE


func heal_full() -> void:
	_health.reset_full()


## Kill floors and other instant-death hazards.
func kill() -> void:
	_health.kill()


func is_alive() -> bool:
	return state != State.DEAD


func is_grappling() -> bool:
	return state == State.GRAPPLE


func is_dashing() -> bool:
	return state == State.DASH


func attack_reach() -> float:
	return 10.0 + form.attack_range


func get_camera_rig() -> CameraRig:
	return _camera


# ── physics ──

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		velocity.y = minf(velocity.y + form.fall_gravity() * delta, MAX_FALL_SPEED)
		move_and_slide()
		return

	_tick_timers(delta)
	_handle_transform_input()

	match state:
		State.MOVE:
			_process_move(delta)
		State.DASH:
			_process_dash(delta)
		State.GRAPPLE:
			_process_grapple(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()
	_post_move(delta)


func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_transform_cooldown = maxf(0.0, _transform_cooldown - delta)
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER


func _handle_transform_input() -> void:
	# Only transform while in normal control; mid-dash/grapple swaps would
	# leave the state machine running a verb the new form doesn't own.
	# Folded chairs must unfold first (otherwise a non-folding form could be
	# stuck 20px tall forever inside a vent).
	if state != State.MOVE or folded or _transform_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("transform_next"):
		GameState.cycle_form(1)
		_transform_cooldown = TRANSFORM_COOLDOWN
	elif Input.is_action_just_pressed("transform_prev"):
		GameState.cycle_form(-1)
		_transform_cooldown = TRANSFORM_COOLDOWN


func _process_move(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var speed := FOLD_SPEED if folded else form.run_speed
	if _rock_charge > 0.0 and form.id == &"rocking":
		speed = ROCK_CHARGE_SPEED  # planted while rocking up a charge
	var accel := form.accel if is_on_floor() else form.accel * form.air_control
	if dir != 0.0:
		if signf(dir) != signf(velocity.x) and velocity.x != 0.0:
			accel = form.decel
		velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
		facing = signf(dir)
		_visual.set_facing(facing)
		_camera.set_facing(facing)
	else:
		velocity.x = move_toward(velocity.x, 0.0, form.decel * delta)

	_apply_gravity(delta)

	# Jump: buffered + coyote. Folded jump = spring launch.
	if _jump_buffer > 0.0 and (is_on_floor() or _coyote > 0.0):
		_jump_buffer = 0.0
		_coyote = 0.0
		if folded:
			_spring_jump()
		else:
			velocity.y = form.jump_velocity()
			_jump_cut_done = false
			_visual.play_jump()
			Events.sfx_requested.emit(&"jump")
	# Variable height: one-shot cut on release while rising.
	if not _jump_cut_done and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT
		_jump_cut_done = true

	_handle_attack()
	_handle_special()


func _apply_gravity(delta: float) -> void:
	if _spring_active and (velocity.y >= 0.0 or is_on_floor()):
		_spring_active = false
	var rising_held := velocity.y < 0.0 and Input.is_action_pressed("jump") and not _jump_cut_done
	var g := form.rise_gravity() if (rising_held or (_spring_active and velocity.y < 0.0)) else form.fall_gravity()
	velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)


func _spring_jump() -> void:
	_set_folded(false)
	if folded:
		return  # no headroom to unfold (inside a vent): no launch, keep crawling
	# Fixed-height launch derived the same way as normal jumps.
	velocity.y = -sqrt(2.0 * form.rise_gravity() * SPRING_HEIGHT)
	_jump_cut_done = true  # springs are full-commitment
	_spring_active = true
	_visual.play_jump()
	Events.sfx_requested.emit(&"spring")


func _handle_attack() -> void:
	if folded or _attack_cooldown > 0.0:
		return
	if not Input.is_action_just_pressed("attack"):
		return
	_attack_cooldown = form.attack_cooldown
	var hit_shape := _hitbox.get_child(0) as CollisionShape2D
	hit_shape.position = Vector2(facing * (10.0 + form.attack_range / 2.0), -28.0)
	_hitbox.knockback_strength = 300.0
	_hitbox.activate(0.12)
	_visual.play_attack()
	Events.sfx_requested.emit(&"attack")


func _handle_special() -> void:
	match form.id:
		&"armchair":
			if Input.is_action_just_pressed("special"):
				_try_grapple()
		&"office":
			if Input.is_action_just_pressed("special") and _dash_cooldown <= 0.0 and not folded:
				_start_dash()
		&"folding":
			if Input.is_action_just_pressed("special"):
				_set_folded(not folded)
		&"rocking":
			_handle_rock_charge()


## Rocking Chair: hold special on the ground to rock up momentum; release a
## full charge to launch high (260px — above every jump and the spring).
## The release edge is detected from our own charge state, NOT
## is_action_just_released — synthetic input can miss the stamp boundary.
func _handle_rock_charge() -> void:
	var holding := Input.is_action_pressed("special")
	if holding:
		if not is_on_floor():
			return  # hold the charge frozen mid-air; resume on landing
		if _rock_charge == 0.0:
			Events.sfx_requested.emit(&"telegraph")
		_rock_charge += get_physics_process_delta_time()
		_visual.set_charge(minf(_rock_charge / ROCK_CHARGE_MIN, 1.0))
		return
	if _rock_charge == 0.0:
		return
	# Release edge: we were charging last tick and the button is up now.
	var charged := _rock_charge >= ROCK_CHARGE_MIN
	_rock_charge = 0.0
	_visual.set_charge(0.0)
	if charged and is_on_floor():
		velocity.y = -sqrt(2.0 * form.rise_gravity() * ROCK_LAUNCH_HEIGHT)
		velocity.x += facing * 200.0
		_jump_cut_done = true
		_spring_active = true  # rise under rise-gravity, full commitment
		_launched = true
		# Consume buffer/coyote so a jump pressed just after release can't
		# overwrite the launch with a normal 135px hop.
		_jump_buffer = 0.0
		_coyote = 0.0
		_visual.play_jump()
		Events.sfx_requested.emit(&"spring")


# ── dash ──

func _start_dash() -> void:
	state = State.DASH
	_dash_left = DASH_TIME
	velocity = Vector2(facing * DASH_SPEED, 0.0)
	_set_collider_height(DASH_HEIGHT)
	_visual.play_land(0.6)  # lean-down pose
	Events.sfx_requested.emit(&"dash")


func _process_dash(delta: float) -> void:
	_dash_left -= delta
	velocity.x = facing * DASH_SPEED
	velocity.y = minf(velocity.y + form.fall_gravity() * 0.25 * delta, 300.0)
	if _dash_left <= 0.0:
		state = State.MOVE
		_dash_cooldown = DASH_COOLDOWN
		velocity.x = facing * form.run_speed


func _process_hurt(delta: float) -> void:
	_hurt_left -= delta
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, form.decel * 0.4 * delta)
	if _hurt_left <= 0.0:
		state = State.MOVE


# ── grapple ──

func _try_grapple() -> void:
	var best: Node2D = null
	var best_dist := GRAPPLE_RANGE
	for node in get_tree().get_nodes_in_group("grapple_anchors"):
		var anchor := node as Node2D
		if anchor == null:
			continue
		var to_anchor := anchor.global_position - global_position
		var dist := to_anchor.length()
		if dist > best_dist:
			continue
		# Accept anchors ahead of us or meaningfully above.
		if signf(to_anchor.x) != facing and to_anchor.y > -40.0:
			continue
		best = anchor
		best_dist = dist
	if best == null:
		Events.sfx_requested.emit(&"grapple_miss")
		return
	_grapple_target = best
	state = State.GRAPPLE
	_jump_cut_done = true
	_rope.visible = true
	Events.sfx_requested.emit(&"grapple")


func _process_grapple(_delta: float) -> void:
	if _grapple_target == null or not is_instance_valid(_grapple_target):
		_release_grapple(false)
		return
	var to_target := _grapple_target.global_position - global_position
	if to_target.length() <= GRAPPLE_ARRIVE_DIST:
		_release_grapple(true)
		return
	if not Input.is_action_pressed("special"):
		_release_grapple(true)
		return
	velocity = to_target.normalized() * GRAPPLE_SPEED
	_rope.clear_points()
	_rope.add_point(Vector2(0, -34))
	_rope.add_point(to_target + Vector2(0, -34))


func _release_grapple(keep_momentum: bool) -> void:
	if state == State.GRAPPLE:
		state = State.MOVE
	if keep_momentum:
		velocity *= GRAPPLE_KEEP
		# Guarantee a small upward pop so ledge grabs feel generous.
		velocity.y = minf(velocity.y, -220.0)
	_grapple_target = null
	_rope.visible = false
	_rope.clear_points()


# ── fold / collider management ──

func _set_folded(value: bool) -> void:
	if folded == value:
		return
	if not value and not _headroom_clear(STAND_HEIGHT):
		return  # can't unfold inside a vent; try again later
	folded = value
	_set_collider_height(FOLD_HEIGHT if folded else STAND_HEIGHT)
	_visual.set_folded(folded)
	Events.sfx_requested.emit(&"fold")


func _set_collider_height(h: float) -> void:
	var rect: RectangleShape2D = _collider.shape
	rect.size = Vector2(BODY_WIDTH, h)
	_collider.position.y = -h / 2.0
	var hurt_shape := _hurtbox.get_child(0) as CollisionShape2D
	(hurt_shape.shape as RectangleShape2D).size = Vector2(BODY_WIDTH - 6.0, maxf(h - 6.0, 12.0))
	hurt_shape.position.y = -h / 2.0


func _headroom_clear(target_height: float) -> bool:
	# Cast the would-be standing box upward from the feet.
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(BODY_WIDTH - 2.0, target_height - 2.0)
	query.shape = box
	query.transform = Transform2D(0.0, global_position + Vector2(0, -target_height / 2.0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return space.intersect_shape(query, 1).is_empty()


## After a dash ends (or an unfold is desired) inside a low passage, keep the
## low profile until there is headroom.
func _restore_collider_when_clear() -> void:
	var rect: RectangleShape2D = _collider.shape
	var current_h := rect.size.y
	var want_h := FOLD_HEIGHT if folded else STAND_HEIGHT
	if is_equal_approx(current_h, want_h):
		return
	if want_h > current_h and not _headroom_clear(want_h):
		return
	_set_collider_height(want_h)


func _ground_slam() -> void:
	_slam_hitbox.activate(0.15)
	Events.hitstop_requested.emit(0.05)
	Events.screenshake_requested.emit(6.0, 0.3)
	Events.sfx_requested.emit(&"boss_hit")
	Particles.dust(get_parent(), global_position, 1.2)
	# Shatter any cracked floor under (or just below) the feet.
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(BODY_WIDTH + 40.0, 40.0)
	query.shape = box
	query.transform = Transform2D(0.0, global_position + Vector2(0, 14.0))
	query.collision_mask = 1
	for hit in space.intersect_shape(query, 8):
		var collider: Object = hit.get("collider")
		if collider != null and collider.has_method("crack_break"):
			collider.crack_break()


# ── damage ──

func _on_hit_received(hitbox: Hitbox) -> void:
	_health.damage(hitbox.damage, hitbox.knockback_for(self))


func _on_damaged(_amount: float, knockback: Vector2) -> void:
	if state == State.GRAPPLE:
		_release_grapple(false)
	if state == State.DASH:
		state = State.MOVE
		_dash_cooldown = DASH_COOLDOWN
	state = State.HURT
	_hurt_left = 0.25
	velocity = knockback
	_visual.play_hurt()
	Events.hitstop_requested.emit(0.08)
	Events.screenshake_requested.emit(5.0, 0.25)
	Events.sfx_requested.emit(&"hurt")


func _on_died() -> void:
	state = State.DEAD
	_release_grapple(false)
	velocity = Vector2(0, -420.0)  # sad little death hop
	Events.screenshake_requested.emit(7.0, 0.4)
	Events.sfx_requested.emit(&"death")
	Events.player_died.emit()


# ── post-move bookkeeping ──

func _post_move(delta: float) -> void:
	if state != State.DASH:
		_restore_collider_when_clear()
	# Landing feedback scaled by impact speed.
	if not _was_on_floor and is_on_floor():
		var intensity := clampf(_fall_peak_speed / MAX_FALL_SPEED, 0.15, 1.0)
		_visual.play_land(intensity)
		if _fall_peak_speed > 300.0:
			Events.sfx_requested.emit(&"land")
			Particles.dust(get_parent(), global_position, intensity)
		# Rocking slam: a launched (or very heavy) landing shocks the ground
		# and shatters cracked floors underfoot.
		if form.id == &"rocking" and (_launched or _fall_peak_speed > SLAM_FALL_SPEED):
			_ground_slam()
		_launched = false
		_fall_peak_speed = 0.0
	if velocity.y > _fall_peak_speed:
		_fall_peak_speed = velocity.y
	_was_on_floor = is_on_floor()
	_visual.update_motion(velocity, is_on_floor(), delta)
