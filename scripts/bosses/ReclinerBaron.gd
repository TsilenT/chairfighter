## ReclinerBaron.gd — A simple placeable miniboss with two attack patterns.
##
## Visual: Purple placeholder with "RECLINING BARON" label.
## When defeated: turns gray, fades out, and queue_free().
##
## Attack patterns (timer-based, no complex AI):
##   IDLE     : wanders back and forth slowly on X, waits randomly.
##   PREP_SWIPE: yellow wind-up for 0.5s, then a Hitbox extends right for 0.3s.
##   LURGE    : darts upward on Y for 0.6s, then drops back.
##
## Combat: SwipeHitbox uses the Hitbox component class (layer 5) which
## automatically collides with Player's Hurtbox (layer 4). The
## hitbox_entered signal fires with the Player's Hurtbox area as argument.
##
## Take damage via the Health component by calling take_damage(amount, knockback).

extends CharacterBody2D

class_name ReclinerBaron

signal defeated


## Boss tuning
@export var max_health: float = 20.0
@export var idle_wander_speed: float = 60.0      ## pixels/sec while wandering
@export var idle_wait_max:   float = 2.0          ## max pause between movements
@export var swipe_prep_time: float = 0.5           ## wind-up duration
@export var swipe_active:   float = 0.3            ## hitbox active time
@export var lunge_duration:  float = 0.6           ## forward rush time
@export var lunge_speed:     float = 300.0         ## forward rush speed

## State-enum (int constants for clarity)
enum { IDLE, PREP_SWIPE, SWIPE_ACTIVE, LURGE_FORWARD, LURGE_RETRACT }

var _state: int = IDLE
var _state_timer: float = 0.0
var _wander_dir: float = 1.0                     ## +1 or -1 for horizontal wander

## @onready lookups
@onready var _health: Node = $Health
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _visual: ColorRect = $Visual
@onready var _label: Label = $Visual/Label
@onready var _preparation_label: Label = $Visual/PreparationLabel
@onready var _preparation_panel: ColorRect = $Visual/PreparationPanel
@onready var _swipe_hitbox: Area2D = $SwipeHitbox     ## invisible attack Area2D
@onready var _swipe_col: CollisionShape2D = $SwipeHitbox/SwipeCol

var is_alive: bool = true
var _hit_flash_timer: float = 0.0
var _defeat_timer: float = 0.0
var _fade_out: bool = false


func _ready() -> void:
	_health.max_health = max_health
	_health.current_hp = max_health
	_health.health_changed.connect(_on_hp_changed)
	_health.health_changed.emit(_health.current_hp, _health.max_health)
	_health.died.connect(_on_died)
	_hurtbox.hitbox_entered.connect(_on_hurtbox_hit)
	_swipe_hitbox.damage = 3.0
	_swipe_hitbox.active_duration = swipe_active
	_swipe_hitbox.hit_direction = Vector2.LEFT
	_wander_dir = -1.0
	_state_timer = randf_range(1.0, 2.0)
	_preparation_label.visible = false
	_preparation_panel.visible = false
	_swipe_hitbox.visible = false


func _physics_process(delta: float) -> void:
	## Hit-flash recovery
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_visual.color = _boss_color()

	## Defeat fade
	if _fade_out:
		_defeat_timer -= delta
		if _visual:
			var new_alpha = clamp(_defeat_timer / 0.5, 0.0, 1.0)
			_visual.color = Color(0.5, 0.5, 0.5, new_alpha)
		if _defeat_timer <= 0.0 and is_alive:
			is_alive = false
			defeated.emit()
			queue_free()
		return

	## State machine
	_state_timer -= delta
	match _state:
		IDLE:
			## Wander while waiting for the next clear attack wind-up.
			global_position.x += _wander_dir * idle_wander_speed * delta
			## Decide next action
			if _state_timer <= 0:
				_wander_dir = -_wander_dir
				_pick_random_action()

		PREP_SWIPE:
			_visual.color = Color(1.0, 0.85, 0.0, 1)   ## yellow wind-up
			_preparation_label.visible = true
			_preparation_label.text = "CHARGING!"
			_preparation_panel.visible = true
			if _state_timer <= 0:
				_state = SWIPE_ACTIVE
				_state_timer = swipe_active
				_swipe_hitbox.visible = true
				_swipe_hitbox.activate()

		SWIPE_ACTIVE:
			_visual.color = Color(1.0, 0.5, 0.0, 1)   ## orange active
			if _state_timer <= 0:
				_swipe_hitbox.deactivate()
				_swipe_hitbox.visible = false
				_preparation_label.visible = false
				_preparation_panel.visible = false
				_visual.color = _boss_color()
				_state = IDLE
				_state_timer = randf_range(1.0, 2.5)

		LURGE_FORWARD:
			global_position.y -= lunge_speed * delta
			if _state_timer <= 0:
				_state = LURGE_RETRACT
				_state_timer = lunge_duration

		LURGE_RETRACT:
			global_position.y += lunge_speed * delta
			if _state_timer <= 0:
				_visual.color = _boss_color()
				_state = IDLE
				_state_timer = randf_range(1.0, 2.5)


## ------------------------------------------------------------------
## Internal helpers
## ------------------------------------------------------------------

func _boss_color() -> Color:
	return Color(0.55, 0.25, 0.75, 1)  ## purple placeholder


func _pick_random_action() -> void:
	var r = randf()
	if r < 0.5:
		_state = PREP_SWIPE
		_state_timer = swipe_prep_time
	else:
		_state = LURGE_FORWARD
		_state_timer = lunge_duration


# ---------- damage reception (Hurtbox receives → Health handles it) ----------

func _on_hurtbox_hit(hitbox_area: Area2D) -> void:
	if not is_alive:
		return
	if not (hitbox_area is Hitbox):
		return
	_visual.color = Color(1.0, 1.0, 1.0, 1)
	_hit_flash_timer = 0.1

	var damage_amount = hitbox_area.damage
	var kb = -hitbox_area.hit_direction.normalized()
	print("[ReclinerBaron] Took %.1f damage!" % damage_amount)
	_health.take_damage(damage_amount, kb)


func _on_hp_changed(current_hp: float, hp_max: float) -> void:
	_label.text = "BARON %.0f/%.0f" % [current_hp, hp_max]


func _on_died() -> void:
	if _fade_out:
		return
	_swipe_hitbox.deactivate()
	_swipe_hitbox.visible = false
	_hurtbox.monitoring = false
	_preparation_label.visible = false
	_preparation_panel.visible = false
	_fade_out = true
	_defeat_timer = 0.5

	## Unlock the Armchair form (idempotent — harmless if already unlocked)
	GameState.unlock_form("Armchair")
	print("[ReclinerBaron] Armchair form unlocked!")

