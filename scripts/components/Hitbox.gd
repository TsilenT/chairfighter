## Hitbox.gd — Area2D melee attack hitbox.
##
## Call activate() to briefly activate it. Deactivates after active_duration.
## Detects enemy hurtboxes via mutual-layer area collision.
##
## Layer 5 (bit 4) for hitboxes; Layer 4 (bit 3) for hurtboxes.

extends Area2D

class_name Hitbox

@export var damage: float = 2.0
@export var hit_direction: Vector2 = Vector2.RIGHT
@export var active_duration: float = 0.15
@export var cooldown_duration: float = 0.3

var _active: bool = false
var _active_timer: float = 0.0
var _cooldown_timer: float = 0.0

# Collision layer numbers (Godot's set_collision_*_value API is 1-indexed)
const LAYER_HURTBOX := 4  # bit 3 — damage receiver areas
const LAYER_HITBOX  := 5  # bit 4 — melee attack areas


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(LAYER_HITBOX, true)
	set_collision_mask_value(LAYER_HURTBOX, true)
	monitoring = false
	monitorable = true
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _active:
		_active_timer -= delta
		if _active_timer <= 0.0:
			deactivate()
	elif _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func activate() -> bool:
	if _cooldown_timer > 0.0 or _active:
		return false
	_active = true
	_active_timer = active_duration
	monitoring = true
	return true


func deactivate() -> void:
	_active = false
	_cooldown_timer = cooldown_duration
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	"""Detect overlapping hurtbox areas."""
	if area is Hurtbox:
		hitbox_entered.emit(area)

signal hitbox_entered(area: Area2D)
