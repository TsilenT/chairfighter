## BasicChairForm.gd — Default starting chair form.
##
## Standard wooden chair with basic movement and melee attack.
## No special mechanics — pure baseline platformer form.

extends RefCounted
class_name BasicChairForm

## Name of this form (used for switching and display).
@export var form_name: String = "BasicChair"

## Whether this form is unlocked.
@export var is_unlocked: bool = true

## Movement properties (delegated by Player per active form).
@export var max_speed: float = 280.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2000.0
@export var air_control: float = 0.5
@export var jump_velocity: float = -520.0
@export var gravity_scale: float = 3.5

## Collision shape size override (Vector2.ZERO = no change).
@export var collision_shape: Vector2 = Vector2.ZERO

## Visual properties for placeholder rendering.
@export var body_color: Color = Color(0.55, 0.45, 0.3, 1)
@export var label_color: Color = Color.WHITE
@export var label_text: String = "Basic Chair"

## Called when the player's attack (Melee) is performed.
func on_attack() -> void:
	"""Extend body forward for a short animation frame."""
	## TODO: animate the ChairBody extending forward (scale.x temporarily)
	pass
