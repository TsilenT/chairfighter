class_name BossBase
extends CharacterBody2D
## Boss chassis. Subclasses define `_patterns()` (array of async Callables)
## and optionally `_on_phase_two()`. The base handles: trigger activation,
## arena camera lock, HUD bar wiring, phase switch at 50%, defeat →
## flag + form unlock + arena release, and full reset when the player dies.
##
## Scene contract for subclass scenes:
##   Root: the subclass script (this base). Origin at FEET.
##   TriggerZone: Area2D + shape — player entering starts the fight.
##   Optional Blocker: StaticBody2D enabled during the fight (shut door).
## Export arena_rect in ZONE coordinates (zones sit at the world origin).

@export var boss_id: StringName = &"boss"
@export var display_name: String = "Boss"
@export var max_health := 40.0
## Form granted on defeat (empty = none, e.g. the final boss).
@export var unlock_form_id: StringName = &""
@export var arena_rect := Rect2(0, 0, 1152, 648)
@export var body_half_width := 60.0
@export var body_height := 120.0
@export var contact_damage := 1.0
@export var touch_hurts := true

const GRAVITY := 2600.0

var health: Health
var phase := 1
var active := false
var defeated := false
var use_gravity := true

var _spawn_pos := Vector2.ZERO
var _hurt_flash := 0.0
var _run_token := 0  # invalidates in-flight pattern coroutines on reset
var _loop_id := 0    # each trigger starts a fresh loop; stale loops die


func _ready() -> void:
	# A boss beaten in a previous visit stays beaten.
	if GameState.has_flag("boss_%s_defeated" % boss_id):
		queue_free()
		return
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	_spawn_pos = global_position

	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_half_width * 2.0, body_height)
	collider.shape = rect
	collider.position = Vector2(0, -body_height / 2.0)
	add_child(collider)

	health = Health.new()
	health.max_health = max_health
	health.invuln_time = 0.12
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	add_child(health)

	var hurtbox := Hurtbox.new()
	hurtbox.faction = &"enemy"
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = rect.duplicate()
	hurt_shape.position = collider.position
	hurtbox.add_child(hurt_shape)
	hurtbox.hit_received.connect(_on_hit_received)
	add_child(hurtbox)

	if touch_hurts:
		var contact := Hitbox.new()
		contact.faction = &"enemy"
		contact.damage = contact_damage
		contact.continuous = true
		contact.rehit_interval = 1.0
		contact.knockback_strength = 340.0
		var contact_shape := CollisionShape2D.new()
		var contact_rect: RectangleShape2D = rect.duplicate()
		contact_rect.size -= Vector2(8, 8)
		contact_shape.shape = contact_rect
		contact_shape.position = collider.position
		contact.add_child(contact_shape)
		add_child(contact)

	var trigger := get_node_or_null("TriggerZone") as Area2D
	if trigger != null:
		trigger.collision_layer = 32
		trigger.collision_mask = 2
		trigger.monitorable = false
		trigger.body_entered.connect(_on_trigger)
	else:
		push_warning("[%s] no TriggerZone; boss will never activate" % boss_id)
	_set_blocker(false)

	Events.player_died.connect(_on_player_died)


func defeat_flag() -> String:
	return "boss_%s_defeated" % boss_id


# ── activation / reset ──

func _on_trigger(body: Node2D) -> void:
	if active or defeated or not body.is_in_group("player"):
		return
	active = true
	Events.boss_started.emit(boss_id, display_name)
	Events.boss_health_changed.emit(boss_id, health.current, health.max_health)
	Events.sfx_requested.emit(&"boss_start")
	_lock_camera(true)
	_set_blocker(true)
	_start_pattern_loop()


func _on_player_died() -> void:
	if defeated or not active:
		return
	# Reset stance/position, but keep most damage dealt (casual difficulty):
	# dying at 1 HP shouldn't erase the whole attempt. Boss recovers 15%.
	active = false
	_run_token += 1
	health.current = minf(health.current + health.max_health * 0.15, health.max_health)
	health.changed.emit(health.current, health.max_health)
	global_position = _spawn_pos
	velocity = Vector2.ZERO
	phase = 1 if health.current > health.max_health * 0.5 else 2
	_lock_camera(false)
	_set_blocker(false)


func _lock_camera(lock: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_camera_rig"):
		return
	var rig: CameraRig = player.get_camera_rig()
	if lock:
		rig.lock_to(arena_rect)
	else:
		rig.unlock()


func _set_blocker(on: bool) -> void:
	var blocker := get_node_or_null("Blocker")
	if blocker == null:
		return
	for child in blocker.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not on)
	(blocker as Node2D).visible = on


# ── combat ──

func _on_hit_received(hb: Hitbox) -> void:
	if not active or defeated:
		return
	if health.damage(hb.damage, hb.knockback_for(self)):
		Events.boss_health_changed.emit(boss_id, health.current, health.max_health)
		Events.hitstop_requested.emit(0.06)
		Events.sfx_requested.emit(&"boss_hit")
		if phase == 1 and health.current <= health.max_health * 0.5:
			phase = 2
			Events.sfx_requested.emit(&"boss_rage")
			_on_phase_two()


func _on_damaged(_amount: float, _knockback: Vector2) -> void:
	_hurt_flash = 1.0  # bosses don't get knocked around


func _on_died() -> void:
	defeated = true
	active = false
	_run_token += 1
	GameState.set_flag(defeat_flag())
	Events.boss_defeated.emit(boss_id)
	Events.sfx_requested.emit(&"boss_down")
	Events.hitstop_requested.emit(0.35)
	Events.screenshake_requested.emit(8.0, 0.5)
	Particles.confetti(get_parent(), global_position + Vector2(0, -body_height / 2.0))
	_lock_camera(false)
	_set_blocker(false)
	if unlock_form_id != &"":
		GameState.unlock_form(unlock_form_id)
	collision_layer = 0
	for child in get_children():
		if child is Area2D:
			(child as Area2D).set_deferred("monitoring", false)
			(child as Area2D).set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "rotation", 0.5, 0.6)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.4)
	tween.tween_callback(queue_free)


# ── pattern engine ──

func _start_pattern_loop() -> void:
	# Always start a fresh loop; any stale loop notices the id change at its
	# next check and unwinds (a brief overlap is harmless — the stale loop's
	# helpers are already dead via _run_token).
	_loop_id += 1
	_pattern_loop.call_deferred(_loop_id)


func _pattern_loop(my_loop: int) -> void:
	var token := _run_token
	while active and not defeated and token == _run_token and my_loop == _loop_id:
		var patterns := _patterns()
		if patterns.is_empty():
			push_warning("[%s] no patterns" % boss_id)
			break
		var pattern: Callable = patterns[randi() % patterns.size()]
		await pattern.call()
		if token != _run_token or my_loop != _loop_id:
			break
		await wait(0.5 if phase == 2 else 0.8)
	# If the fight restarts later (player died), the trigger starts a new loop.


## Subclass hook: list of async pattern Callables.
func _patterns() -> Array[Callable]:
	return []


## Subclass hook: called once at 50% health.
func _on_phase_two() -> void:
	pass


func _physics_process(delta: float) -> void:
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 6.0)
	if defeated:
		return
	if use_gravity and not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	queue_redraw()


# ── pattern helpers for subclasses ──

func player_node() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func dir_to_player() -> float:
	var p := player_node()
	if p == null:
		return 1.0
	return signf(p.global_position.x - global_position.x)


## Flash + pause so every attack has a readable tell.
func telegraph(duration: float) -> void:
	Events.sfx_requested.emit(&"telegraph")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.6, 1.4, 0.9), duration * 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, duration * 0.5)
	await wait(duration)


## Physics-time wait that dies with the current run (reset-safe) and does
## not advance while the game is paused (physics_frame still fires then).
func wait(seconds: float) -> void:
	var token := _run_token
	var left := seconds
	while left > 0.0 and token == _run_token and not defeated and active:
		await get_tree().physics_frame
		if not can_process():
			continue  # paused: hold time still
		left -= get_physics_process_delta_time()


## Glide horizontally toward x until arrival or timeout. Returns on arrival.
func move_to_x(x: float, speed: float, timeout := 4.0) -> void:
	var token := _run_token
	var left := timeout
	while token == _run_token and not defeated and active and left > 0.0:
		var dx := x - global_position.x
		if absf(dx) < 12.0:
			break
		velocity.x = signf(dx) * speed
		await get_tree().physics_frame
		if not can_process():
			continue
		left -= get_physics_process_delta_time()
	velocity.x = 0.0


func hop(vel: Vector2) -> void:
	velocity = vel


func spawn_projectile(from: Vector2, vel: Vector2, proj_color := Color(0.85, 0.6, 0.3), proj_radius := 10.0) -> void:
	if not active or defeated:
		return  # stale pattern unwinding after a reset must not spawn hazards
	var proj := Projectile.new()
	proj.velocity = vel
	proj.color = proj_color
	proj.radius = proj_radius
	get_parent().add_child(proj)
	proj.global_position = from
	Events.sfx_requested.emit(&"lob")
